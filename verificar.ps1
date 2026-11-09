# verificar.ps1 - Revisa la etapa 1
# Se corre desde la carpeta del proyecto:   .\verificar.ps1

$env:Path += ";C:\Program Files\PostgreSQL\18\bin"
$env:PGCLIENTENCODING = "UTF8"
if (-not $env:PGPASSWORD) { $env:PGPASSWORD = Read-Host "Contrasena de postgres" }

function Mostrar($texto, $ok) {
    if ($ok) { Write-Host "[OK]    $texto" -ForegroundColor Green }
    else     { Write-Host "[FALTA] $texto" -ForegroundColor Red }
}

function Numero($sql) {
    $r = psql -U postgres -d bodegas -At -c $sql | Select-Object -First 1
    return [int]$r
}

function Contar($archivo, $patron) {
    return @(Get-Content $archivo -Encoding UTF8 | Select-String -Pattern $patron).Count
}

Write-Host "--- Base de datos ---"
$tablas = Numero "SELECT count(*) FROM pg_tables WHERE schemaname='public'"
Mostrar "26 tablas (hay $tablas)" ($tablas -eq 26)

$float = Numero "SELECT count(*) FROM pg_attribute a JOIN pg_class c ON c.oid=a.attrelid WHERE c.relnamespace='public'::regnamespace AND c.relkind='r' AND a.attnum>0 AND NOT a.attisdropped AND a.atttypid IN ('float4'::regtype,'float8'::regtype)"
Mostrar "Ningun importe usa FLOAT (hay $float)" ($float -eq 0)

$enums = Numero "SELECT count(*) FROM pg_type WHERE typtype='e' AND typnamespace='public'::regnamespace"
Mostrar "2 tipos ENUM (hay $enums)" ($enums -eq 2)

Write-Host ""
Write-Host "--- Diccionario ---"
$dic = "docs\02_diccionario_datos.md"
$columnas = Numero "SELECT count(*) FROM pg_attribute a JOIN pg_class c ON c.oid=a.attrelid WHERE c.relnamespace='public'::regnamespace AND c.relkind='r' AND a.attnum>0 AND NOT a.attisdropped"
$filas = Contar $dic '^\| '
Mostrar "Filas del .md ($filas) = columnas reales ($columnas) + 26 encabezados" ($filas -eq $columnas + 26)

$raya = [char]0x2014
$vacias = Contar $dic (" " + $raya + " \|$")
Mostrar "Columnas sin descripcion (hay $vacias)" ($vacias -eq 0)

Write-Host ""
Write-Host "--- Documentos ---"
Mostrar "docs\der\Modelo_Integrador.pdf" (Test-Path "docs\der\Modelo_Integrador.pdf")
Mostrar "docs\der\modelo.dbml" (Test-Path "docs\der\modelo.dbml")

$modelo = "docs\01_modelo.md"
$temas = @("esquema relacional", "Dependencias funcionales", "Dependencias parciales", "Dependencias transitivas", "Jerarqu", "Claves", "Tipos de datos", "Atributos derivados", "acciones referenciales", "NUMERIC", "ON DELETE")
foreach ($t in $temas) {
    $n = Contar $modelo $t
    Mostrar "01_modelo.md habla de: $t" ($n -gt 0)
}

Write-Host ""
Write-Host "--- Git (la rubrica descuenta si hay un solo integrante) ---"
git shortlog -sn
