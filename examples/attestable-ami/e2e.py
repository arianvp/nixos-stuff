"""Tests the examples end to end on EC2, against the real NitroTPM, KMS and
IMDS that the VM tests only stand in for.


It creates a KMS key, an IAM role, an Elastic IP, a security group, AMIs and
instances, all tagged with the run, and removes them again on exit, except for
the key, which KMS only deletes after 7 days. KEEP=1 keeps everything.
"""

import base64
import concurrent.futures
import contextlib
import datetime
import hashlib
import ipaddress
import json
import os
import re
import ssl
import subprocess
import sys
import time
import urllib.request

import boto3
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.x509.oid import NameOID


ALIAS = "@alias@"
IMAGE = "@image@"
PCRS = "@pcrs@"
PREDICT_PCR12 = "@predict_pcr12@"
UEFI_DATA = "@uefi_data@"
OTHER_UEFI_DATA = "@other_uefi_data@"
SANDBOX = "@sandbox@"


# Enclaves need at least 4 vCPUs.
INSTANCE_TYPE = os.environ.get("INSTANCE_TYPE", "m7i.xlarge")
RUN = f"attestable-ami-e2e-{int(time.time())}"
TAG = {"Key": "attestable-ami-e2e", "Value": RUN}
# Instances start and terminate within a minute or two.
WAIT = {"Delay": 5, "MaxAttempts": 24}
# An instance stuck in the firmware takes longer to go, and holds on to the
# security group until it has.
TERMINATE = {"Delay": 10, "MaxAttempts": 30}
# The EBS direct APIs take snapshots in blocks of 512 KiB. A few at a time
# keep each one within its timeout on a slow uplink.
BLOCK = 512 * 1024
UPLOAD_THREADS = 8


ec2 = boto3.client("ec2")
iam = boto3.client("iam")
kms = boto3.client("kms")
ebs = boto3.client("ebs")


failures = []


def log(message):
    print(f"[{RUN}] {message}", file=sys.stderr, flush=True)


def check(ok, message):
    log(("PASS: " if ok else "FAIL: ") + message)
    if not ok:
        failures.append(message)


def tags(resource_type):
    return [{"ResourceType": resource_type, "Tags": [TAG]}]


def retry(action, retryable, what):
    """Retries while IAM changes propagate."""
    for attempt in range(12):
        try:
            return action()
        except Exception as error:
            if not retryable(error):
                raise
            time.sleep(5)
    raise RuntimeError(f"{what} never became usable")


def create_key(cleanup, account):
    # The account may administer the key, but nobody may decrypt with it
    # until the policy names the instance role and its PCRs.
    policy = {
        "Version": "2012-10-17",
        "Statement": [{
            "Sid": "Administer",
            "Effect": "Allow",
            "Principal": {"AWS": f"arn:aws:iam::{account}:root"},
            "NotAction": "kms:Decrypt",
            "Resource": "*",
        }],
    }
    key = kms.create_key(
        Policy=json.dumps(policy),
        Description=RUN,
        Tags=[{"TagKey": TAG["Key"], "TagValue": TAG["Value"]}],
    )["KeyMetadata"]["Arn"]
    cleanup.callback(kms.schedule_key_deletion, KeyId=key, PendingWindowInDays=7)
    # The image decrypts with whatever key the alias points at.
    try:
        kms.create_alias(AliasName=ALIAS, TargetKeyId=key)
    except kms.exceptions.AlreadyExistsException:
        kms.update_alias(AliasName=ALIAS, TargetKeyId=key)
    cleanup.callback(kms.delete_alias, AliasName=ALIAS)
    return key, policy


def create_role(cleanup):
    role = iam.create_role(
        RoleName=RUN,
        Tags=[TAG],
        AssumeRolePolicyDocument=json.dumps({
            "Version": "2012-10-17",
            "Statement": [{
                "Effect": "Allow",
                "Principal": {"Service": "ec2.amazonaws.com"},
                "Action": "sts:AssumeRole",
            }],
        }),
    )["Role"]["Arn"]
    cleanup.callback(iam.delete_role, RoleName=RUN)
    iam.create_instance_profile(InstanceProfileName=RUN)
    cleanup.callback(iam.delete_instance_profile, InstanceProfileName=RUN)
    iam.add_role_to_instance_profile(InstanceProfileName=RUN, RoleName=RUN)
    cleanup.callback(
        iam.remove_role_from_instance_profile,
        InstanceProfileName=RUN,
        RoleName=RUN,
    )
    return role


def certify(public_key_der, address):
    """A throwaway CA, and its certificate for a public key whose private
    half it never sees. Python verifies strictly, so both carry the
    extensions RFC 5280 asks for."""
    ca_key = ec.generate_private_key(ec.SECP256R1())
    ca_name = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, RUN)])
    now = datetime.datetime.now(datetime.timezone.utc)

    def certificate(subject, public_key, *extensions):
        builder = (
            x509.CertificateBuilder()
            .subject_name(subject)
            .issuer_name(ca_name)
            .public_key(public_key)
            .serial_number(x509.random_serial_number())
            .not_valid_before(now)
            .not_valid_after(now + datetime.timedelta(days=1))
            .add_extension(x509.SubjectKeyIdentifier.from_public_key(public_key), critical=False)
            .add_extension(
                x509.AuthorityKeyIdentifier.from_issuer_public_key(ca_key.public_key()),
                critical=False,
            )
        )
        for extension, critical in extensions:
            builder = builder.add_extension(extension, critical=critical)
        return builder.sign(ca_key, hashes.SHA256()).public_bytes(serialization.Encoding.PEM).decode()

    def key_usage(**usages):
        flags = (
            "digital_signature", "content_commitment", "key_encipherment", "data_encipherment",
            "key_agreement", "key_cert_sign", "crl_sign", "encipher_only", "decipher_only",
        )
        return x509.KeyUsage(**{flag: usages.get(flag, False) for flag in flags}), True

    ca = certificate(
        ca_name,
        ca_key.public_key(),
        (x509.BasicConstraints(ca=True, path_length=0), True),
        key_usage(key_cert_sign=True, crl_sign=True),
    )
    leaf = certificate(
        x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, address)]),
        serialization.load_der_public_key(public_key_der),
        (x509.SubjectAlternativeName([x509.IPAddress(ipaddress.ip_address(address))]), False),
        key_usage(digital_signature=True),
        (x509.ExtendedKeyUsage([x509.oid.ExtendedKeyUsageOID.SERVER_AUTH]), False),
    )
    return ca, leaf


def upload(cleanup, image_file):
    """Uploads the image straight into a snapshot with the EBS direct APIs,
    leaving out the blocks that are all zeros."""
    size = os.path.getsize(image_file)
    snapshot = ebs.start_snapshot(
        VolumeSize=-(-size // 2**30),
        Tags=[{"Key": TAG["Key"], "Value": TAG["Value"]}],
    )["SnapshotId"]
    cleanup.callback(ec2.delete_snapshot, SnapshotId=snapshot)
    blocks = -(-size // BLOCK)
    log(f"uploading {image_file} ({size // 2**20} MiB) to {snapshot}")

    def put(index):
        with open(image_file, "rb") as f:
            f.seek(index * BLOCK)
            data = f.read(BLOCK).ljust(BLOCK, b"\0")
        if not data.strip(b"\0"):
            return 0
        ebs.put_snapshot_block(
            SnapshotId=snapshot,
            BlockIndex=index,
            BlockData=data,
            DataLength=BLOCK,
            Checksum=base64.b64encode(hashlib.sha256(data).digest()).decode(),
            ChecksumAlgorithm="SHA256",
        )
        return 1

    changed = 0
    with concurrent.futures.ThreadPoolExecutor(UPLOAD_THREADS) as pool:
        for done, put_block in enumerate(pool.map(put, range(blocks)), 1):
            changed += put_block
            if done % 100 == 0 or done == blocks:
                log(f"{snapshot}: {done}/{blocks} blocks")
    ebs.complete_snapshot(SnapshotId=snapshot, ChangedBlocksCount=changed)
    ec2.get_waiter("snapshot_completed").wait(SnapshotIds=[snapshot], WaiterConfig=WAIT)
    return snapshot


def register(cleanup, name, snapshot, **register):
    ami = ec2.register_image(
        Name=f"{RUN}-{name}",
        Architecture="x86_64",
        EnaSupport=True,
        VirtualizationType="hvm",
        RootDeviceName="/dev/xvda",
        BlockDeviceMappings=[{"DeviceName": "/dev/xvda", "Ebs": {"SnapshotId": snapshot}}],
        TagSpecifications=tags("image"),
        **register,
    )["ImageId"]
    cleanup.callback(ec2.deregister_image, ImageId=ami)
    return ami


def launch(cleanup, ami, group, **run):
    """Launches an instance without waiting for it to run, so that the
    instances of a run boot side by side."""
    instance = retry(
        lambda: ec2.run_instances(
            ImageId=ami,
            InstanceType=INSTANCE_TYPE,
            MinCount=1,
            MaxCount=1,
            SecurityGroupIds=[group],
            TagSpecifications=tags("instance"),
            **run,
        )["Instances"][0]["InstanceId"],
        lambda error: "Invalid IAM Instance Profile" in str(error),
        "the instance profile",
    )
    cleanup.callback(
        ec2.get_waiter("instance_terminated").wait, InstanceIds=[instance], WaiterConfig=TERMINATE
    )
    # Nothing on the instance needs a clean shutdown.
    cleanup.callback(ec2.terminate_instances, InstanceIds=[instance], SkipOsShutdown=True)
    return instance


# Decrypting comes last, after the PCRs and security state are logged.
DECRYPTED = r"(Finished|Failed to start) Decrypt example"


def console(instance, done, timeout=120):
    """Waits until the serial console shows `done`, and returns all of it, so
    that everything else is checked against what is there by then."""
    deadline = time.monotonic() + timeout
    while True:
        # boto3 decodes the base64 of the API already. systemd colours its
        # status lines, which would break up the patterns.
        text = re.sub(
            r"\x1b\[[0-9;:]*m",
            "",
            ec2.get_console_output(InstanceId=instance, Latest=True).get("Output", ""),
        )
        if re.search(done, text, re.I) or time.monotonic() > deadline:
            # Kept, as the instance is gone after the run.
            with open(f"{instance}.log", "w") as f:
                f.write(text)
            log(f"console output in {instance}.log")
            return text
        time.sleep(5)


def fetch(url, ca, timeout=30):
    context = ssl.create_default_context(cadata=ca)
    deadline = time.monotonic() + timeout
    while True:
        try:
            with urllib.request.urlopen(url, context=context, timeout=5) as response:
                return response.read().decode()
        except OSError:
            if time.monotonic() > deadline:
                return ""
            time.sleep(5)


def main(cleanup):
    account = boto3.client("sts").get_caller_identity()["Account"]

    log("creating a KMS key nobody may decrypt with yet, and the instance role")
    key, policy = create_key(cleanup, account)
    role = create_role(cleanup)

    log("allocating an Elastic IP, and a security group for HTTPS from here")
    eip = ec2.allocate_address(TagSpecifications=tags("elastic-ip"))
    cleanup.callback(ec2.release_address, AllocationId=eip["AllocationId"])
    address = eip["PublicIp"]
    group = ec2.create_security_group(
        GroupName=RUN, Description=RUN, TagSpecifications=tags("security-group")
    )["GroupId"]
    cleanup.callback(ec2.delete_security_group, GroupId=group)
    me = urllib.request.urlopen("https://checkip.amazonaws.com").read().decode().strip()
    ec2.authorize_security_group_ingress(
        GroupId=group, IpProtocol="tcp", FromPort=443, ToPort=443, CidrIp=f"{me}/32"
    )

    log(f"encrypting a secret, and a TLS key pair for {address}")
    ciphertext = kms.encrypt(KeyId=key, Plaintext=os.urandom(32))["CiphertextBlob"]
    pair = kms.generate_data_key_pair_without_plaintext(KeyId=key, KeyPairSpec="ECC_NIST_P256")
    ca, certificate = certify(pair["PublicKey"], address)
    user_data = json.dumps({"systemd.credentials": [
        {"name": "kms.example", "text": base64.b64encode(ciphertext).decode()},
        {"name": "kms.tls-key", "text": base64.b64encode(pair["PrivateKeyCiphertextBlob"]).decode()},
        {"name": "tls.certificate", "text": certificate},
    ]})

    with open(PCRS) as f:
        expected = json.load(f)["Measurements"]
    del expected["HashAlgorithm"]
    expected["PCR12"] = subprocess.run(
        [PREDICT_PCR12, "/dev/stdin"], input=user_data, check=True, capture_output=True, text=True
    ).stdout.strip()
    log(f"expecting {expected}")

    # PCR 11 would only hold once the system is ready, which nothing waits
    # for before decrypting yet.
    policy["Statement"].append({
        "Sid": "AttestedDecrypt",
        "Effect": "Allow",
        "Principal": {"AWS": role},
        "Action": "kms:Decrypt",
        "Resource": "*",
        "Condition": {"StringEqualsIgnoreCase": {
            f"kms:RecipientAttestation:NitroTPM{pcr}": value
            for pcr, value in expected.items()
            if pcr != "PCR11"
        }},
    })
    retry(
        lambda: kms.put_key_policy(KeyId=key, Policy=json.dumps(policy)),
        lambda error: isinstance(error, kms.exceptions.MalformedPolicyDocumentException),
        "the instance role",
    )

    attestable = {"BootMode": "uefi", "TpmSupport": "v2.0"}
    if UEFI_DATA:
        with open(UEFI_DATA) as f:
            attestable["UefiData"] = f.read().strip()

    snapshot = upload(cleanup, IMAGE)
    ami = register(cleanup, "image", snapshot, **attestable)
    run = {"IamInstanceProfile": {"Name": RUN}}
    if SANDBOX:
        run["EnclaveOptions"] = {"Enabled": True}

    log("launching the image with the user data, and with other user data")
    instance = launch(cleanup, ami, group, UserData=user_data, **run)
    other = launch(cleanup, ami, group, UserData=user_data + "\n", **run)
    instances = [instance, other]
    if OTHER_UEFI_DATA:
        log("and with the Secure Boot variables of a UKI that differs in its command line")
        with open(OTHER_UEFI_DATA) as f:
            other_uefi_data = f.read().strip()
        refused = launch(
            cleanup,
            register(cleanup, "other-db", snapshot, **{**attestable, "UefiData": other_uefi_data}),
            group,
        )
        instances.append(refused)
    ec2.get_waiter("instance_running").wait(InstanceIds=instances, WaiterConfig=WAIT)
    ec2.associate_address(AllocationId=eip["AllocationId"], InstanceId=instance)

    output = console(instance, DECRYPTED)
    for pcr, value in expected.items():
        check(re.search(f"pcr-sha384/{pcr.removeprefix('PCR')}:{value}", output, re.I), f"{pcr} is {value}")
    check(re.search(r"lockdown:.*\[confidentiality\]", output), "the kernel is locked down")
    check("ipe/enforce:1" in output, "IPE enforces")
    check("Finished Decrypt example" in output, "KMS releases the secret")
    check(
        "served by an attested image" in fetch(f"https://{address}/", ca),
        "the instance serves TLS with the key KMS released to it",
    )
    if SANDBOX:
        hello = "Hello from a Nitro Sandbox"
        # The sandbox boots after the parent has, a minute or so after launch.
        check(hello in console(instance, hello, timeout=90), "the instance spawns a Nitro Sandbox")

    check(
        "Failed to start Decrypt example" in console(other, DECRYPTED),
        "KMS refuses the same image with other user data",
    )

    if OTHER_UEFI_DATA:
        # The firmware gives up on the disk, and the kernel never starts. EC2
        # says "No bootable device found", OVMF "Access Denied".
        output = console(refused, "No bootable device|Access Denied")
        check(
            re.search("No bootable device|Access Denied", output) and "Linux version" not in output,
            "Secure Boot refuses a UKI that isn't in db",
        )


def report():
    if failures:
        log(f"{len(failures)} checks failed: {', '.join(failures)}")
    else:
        log("all checks passed")


with contextlib.ExitStack() as cleanup:
    try:
        main(cleanup)
    except BaseException:
        failures.append("the run itself")
        raise
    finally:
        # The verdict doesn't wait for the cleanup.
        report()
        if os.environ.get("KEEP"):
            log(f"keeping everything, see the {TAG['Key']}={RUN} tag")
            cleanup.pop_all()
        else:
            log("cleaning up")

sys.exit(1 if failures else 0)
