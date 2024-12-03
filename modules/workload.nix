{
  # We need swap so that there is time to react to OOM events.  Most of our memory
  # usage is from the Haskell Runtime which will be anonymous pages and can be swapped
  # out without much performance impact due to the GHC runtime overcommitting memory.
  swapDevices = [{ device = "/var/lib/swap"; size = 4 * 1024; }];

  # We consider everything in the system slice to be "critical". Lets give it a guaranteed
  # amount of memory to ensure that it can always run.
  systemd.slices.system.sliceConfig = {
    MemoryMin = "352M";
  };
  systemd.slices.workload = {
    # by having the workload slice start after the system slice we ensure that during
    # shutdown the workload is stopped before the system services.
    # This way we can ensure things like log-shipping are only stopped after
    # the main workload has been stopped.
    after = [ "system.slice" ]; 
    description = "Services considered part of the 'main' workload should be placed in this slice";
    sliceConfig = {
      MemoryLow = "90%";
      ManagedOOMMemoryPressure = "kill";
      ManagedOOMMemoryPressureLimit = "80%";
    };
  };
}