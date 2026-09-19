$env:JAVA_HOME = "C:\Users\KPK\.jdks\jbr-21.0.11"
$env:Path = "$env:JAVA_HOME\bin;" + $env:Path

Write-Output "Using Java:"
java -version

flutter build apk --debug
