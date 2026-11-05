#!/usr/bin/env bash
set -euo pipefail

exec /usr/bin/dotnet run \
  --project /home/luanthanh/Program_File/Div-Acer-Manager-Max/DivAcerManagerMax/DivAcerManagerMax.csproj \
  --no-launch-profile
