# Servidor HTTP mínimo para abrir el juego en el navegador.
# Hace falta porque la cámara solo funciona en "contexto seguro": http://localhost
# (o HTTPS). Abrir el .html con doble clic (file://) puede bloquear la cámara.
# No requiere Python, Node ni permisos de administrador: solo PowerShell.
param([int]$Port = 8788)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

function Send-Response($stream, [int]$code, [string]$type, [byte[]]$body){
  $reason = if($code -eq 200){ 'OK' } else { 'Not Found' }
  $head = "HTTP/1.1 $code $reason`r`n" +
          "Content-Type: $type`r`n" +
          "Content-Length: $($body.Length)`r`n" +
          "Cache-Control: no-store`r`n" +
          "Connection: close`r`n`r`n"
  $hb = [System.Text.Encoding]::ASCII.GetBytes($head)
  $stream.Write($hb, 0, $hb.Length)
  $stream.Write($body, 0, $body.Length)
}

try {
  $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $Port)
  $listener.Start()
} catch {
  # Si el puerto ya está ocupado, probablemente el servidor ya está corriendo.
  Write-Host "El puerto $Port ya está en uso. Probablemente el servidor ya está abierto."
  Write-Host "Abrí: http://localhost:$Port/juego-seguimiento-ocular.html"
  Start-Sleep -Seconds 4
  exit 0
}

Write-Host ""
Write-Host "  Servidor del juego ocular"
Write-Host "  Carpeta: $root"
Write-Host "  Dirección: http://localhost:$Port/juego-seguimiento-ocular.html"
Write-Host ""
Write-Host "  Dejá esta ventana abierta mientras jugás."
Write-Host "  Para terminar el servidor: cerrá esta ventana o pulsá Ctrl+C."
Write-Host ""

while($true){
  $client = $listener.AcceptTcpClient()
  try {
    $stream = $client.GetStream()
    $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::ASCII)
    $line = $reader.ReadLine()
    while($reader.ReadLine()){ }          # descarta el resto de los encabezados

    $path = '/'
    if($line){
      $parts = $line.Split(' ')
      if($parts.Length -ge 2){ $path = $parts[1] }
    }
    $path = $path.Split('?')[0].TrimStart('/')
    if([string]::IsNullOrWhiteSpace($path)){
      $path = 'juego-seguimiento-ocular.html'
    }

    # Normaliza y evita salir de la carpeta servida.
    $full = [System.IO.Path]::GetFullPath((Join-Path $root $path))
    $rootFull = [System.IO.Path]::GetFullPath($root)
    if(-not $full.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)){
      Send-Response $stream 404 'text/plain; charset=utf-8' ([System.Text.Encoding]::UTF8.GetBytes('404'))
      $client.Close()
      continue
    }

    if(Test-Path -LiteralPath $full -PathType Leaf){
      $bytes = [System.IO.File]::ReadAllBytes($full)
      $ext = [System.IO.Path]::GetExtension($full).ToLowerInvariant()
      $type = switch($ext){
        '.html' { 'text/html; charset=utf-8' }
        '.htm'  { 'text/html; charset=utf-8' }
        '.js'   { 'text/javascript; charset=utf-8' }
        '.mjs'  { 'text/javascript; charset=utf-8' }
        '.css'  { 'text/css; charset=utf-8' }
        '.json' { 'application/json; charset=utf-8' }
        '.png'  { 'image/png' }
        '.jpg'  { 'image/jpeg' }
        '.jpeg' { 'image/jpeg' }
        '.svg'  { 'image/svg+xml' }
        '.ico'  { 'image/x-icon' }
        default { 'application/octet-stream' }
      }
      Send-Response $stream 200 $type $bytes
    } else {
      Send-Response $stream 404 'text/plain; charset=utf-8' ([System.Text.Encoding]::UTF8.GetBytes('404'))
    }
    $stream.Flush()
  } catch {
    # Un cliente que corta la conexión no debe tumbar el servidor.
  } finally {
    $client.Close()
  }
}
