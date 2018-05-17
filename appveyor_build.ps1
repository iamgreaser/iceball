if ($env:GENERATOR -eq "MSYS Makefiles")
{
  $env:BUILD_FOLDER = $env:APPVEYOR_BUILD_FOLDER -replace '\\', '\\\\';
  bash -lc "cd $env:BUILD_FOLDER; $env:CMAKE_SCRIPT 2>&1";
} else {
  $env:CMAKE_SCRIPT = $env:CMAKE_SCRIPT -replace '\\', '';
  cmd.exe /c "$env:CMAKE_SCRIPT 2>&1";
}
