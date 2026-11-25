# Predicts PCR 12 for a given user data file. systemd-imds measures the user
# data into PCR 12 before importing credentials from it, so a key policy that
# binds PCR 12 binds the exact user data, too.
{ writers }:
writers.writePython3Bin "predict-pcr12" { } ''
  import base64
  import hashlib
  import sys

  # systemd's pcrextend_imds_userdata_word()
  data = open(sys.argv[1], "rb").read()
  word = "imds-userdata:{}:{}".format(
      hashlib.sha256(data).hexdigest(),
      base64.b64encode(data[:256]).decode(),
  )

  event = hashlib.sha384(word.encode()).digest()
  print(hashlib.sha384(bytes(48) + event).hexdigest())
''
