# MySQL 8.4.7 para Windows Server Core
FROM mcr.microsoft.com/windows/servercore:ltsc2022

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop';"]

# Baixar MySQL
RUN Write-Host 'Baixando MySQL 8.4.7...' ; \
    Invoke-WebRequest -Uri "https://cdn.mysql.com/Downloads/MySQL-8.4/mysql-8.4.7-winx64.zip" -OutFile C:\mysql.zip -UseBasicParsing ; \
    Write-Host 'Extraindo...' ; \
    Expand-Archive -Path C:\mysql.zip -DestinationPath C:\ ; \
    Rename-Item "C:\mysql-8.4.7-winx64" C:\mysql ; \
    Remove-Item C:\mysql.zip -Force ; \
    New-Item -ItemType Directory -Path C:\mysql-data -Force | Out-Null ; \
    New-Item -ItemType Directory -Path C:\mysql\etc -Force | Out-Null

# Copiar configuracao
COPY my.ini C:/mysql/etc/my.ini

# Inicializar banco
RUN Write-Host 'Inicializando MySQL...' ; \
    Start-Process -FilePath 'C:\mysql\bin\mysqld.exe' -ArgumentList '--initialize-insecure', '--basedir=C:\mysql', '--datadir=C:\mysql-data' -Wait -NoNewWindow ; \
    Write-Host 'MySQL inicializado!'

EXPOSE 3306

CMD ["C:\\mysql\\bin\\mysqld.exe", "--defaults-file=C:\\mysql\\etc\\my.ini", "--console"]
