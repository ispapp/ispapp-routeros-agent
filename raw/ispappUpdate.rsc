# communication script with update endpoint
:global sendUpdate;
:global isUpdatebusy;
# Check if Console thread busy if not we run new Console instance;
if (!any$isUpdatebusy) do={
  :set isUpdatebusy true;
}
:if ($isUpdatebusy = false) do={
  :if (any$sendUpdate) do={
    :do {
      :local updates [$sendUpdate];
      :put "sendUpdate done :) with output:\n\r $updates";
    } on-error={
      :put "sendUpdate error!";
    }
  } else={
    :put "Library v4 is not loaded! (not sendUpdate found)";
    :log error "Library v4 is not loaded! (not sendUpdate found)";
  }
}
:set isUpdatebusy false;