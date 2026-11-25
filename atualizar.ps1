# Atualiza o catalogo da loja (loja\produtos.js) a partir do site do fornecedor.
# Uso: clique duas vezes em atualizar.bat  (ou rode: powershell -ExecutionPolicy Bypass -File atualizar.ps1)

# ===================== CONFIGURACAO =====================
$FORNECEDOR = "https://pmcellsaopaulo.com.br"
$MARGEM     = 1.5                     # multiplica o preco do fornecedor
$EXCLUIR    = @("kits")               # colecoes que NAO entram na loja (ex.: @("kits","caixa-fechada"))
$OCULTAR_ESGOTADOS = $true            # esconde produtos sem nenhuma variacao disponivel

# Colecoes usadas como categorias na loja: handle = nome exibido
$CATEGORIAS = [ordered]@{
  "fones"="Fones"; "caixas-de-som"="Caixas de Som"; "bluetooth"="Bluetooth"; "audio"="Áudio";
  "carregadores"="Carregadores"; "cabos"="Cabos"; "adaptadores"="Adaptadores"; "powerbanks"="Power Banks";
  "fontes"="Fontes"; "pelicula"="Películas"; "capa"="Capas"; "suportes"="Suportes";
  "smartwatch"="Relógios"; "mouses-e-teclados"="Mouses e Teclados"; "gamer"="Gamer"; "controles"="Controles";
  "hdmi"="HDMI"; "armazenamento"="Armazenamento"; "eletronicos"="Eletrônicos"; "casa-inteligente"="Casa Inteligente";
  "seguranca"="Segurança"; "automotivo"="Automotivo"; "extensao"="Extensões"; "ferramentas"="Ferramentas";
  "assistencia-tecnica"="Assistência Técnica"; "acessorios"="Acessórios"; "utensilios"="Utilidades";
  "garrafas"="Garrafas"; "brinquedos-1"="Brinquedos"; "papelaria"="Papelaria"; "perfumaria"="Perfumaria"
}
# ========================================================

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$raiz = Split-Path -Parent $MyInvocation.MyCommand.Path
$saida = Join-Path $raiz "loja\produtos.js"

function Get-Json($url) {
  for ($t = 1; $t -le 8; $t++) {
    try {
      $r = Invoke-WebRequest -UseBasicParsing -Uri $url -Headers @{ "Accept" = "application/json" }
      Start-Sleep -Milliseconds 700
      return ($r.Content | ConvertFrom-Json)
    } catch {
      Write-Host "  site pediu uma pausa, aguardando... (tentativa $t)" -ForegroundColor Yellow
      Start-Sleep -Seconds (5 * $t)
    }
  }
  throw "Nao foi possivel baixar $url"
}

function Get-Produtos($base) {
  $lista = @()
  for ($p = 1; $p -le 40; $p++) {
    $j = Get-Json "$base/products.json?limit=250&page=$p"
    if (-not $j.products -or $j.products.Count -eq 0) { break }
    $lista += $j.products
  }
  return $lista
}

function Convert-Texto($html) {
  if (-not $html) { return "" }
  $s = $html -replace '(?i)<br\s*/?>', "`n" -replace '(?i)</(p|li|div|h[1-6]|tr)>', "`n" -replace '(?i)<li[^>]*>', "• "
  $s = $s -replace '<[^>]+>', ''
  $s = [System.Net.WebUtility]::HtmlDecode($s)
  # Remove a secao "PARA A REVENDA" (dicas para lojista) ate o proximo titulo em maiusculas
  $linhas = New-Object System.Collections.ArrayList
  $pulando = $false
  foreach ($l in ($s -split "`n")) {
    $l = $l.Trim()
    if ($l -eq "") { continue }
    $titulo = $l -cmatch '^[A-ZÀ-Ý0-9 /&\-:!?]{6,}$'
    if ($titulo) { $pulando = ($l -match 'REVENDA|LOJISTA|ATACADO') }
    if (-not $titulo) {
      # tira frases soltas voltadas ao lojista ("para revenda em loja de...")
      $l = (($l -split '(?<=[.!?])\s+') | Where-Object { $_ -notmatch '(?i)revend|lojista|atacad' }) -join ' '
      if ($l -eq "") { continue }
    }
    if (-not $pulando) { [void]$linhas.Add($l) }
  }
  $s = ($linhas -join "`n") -replace "•\s*`n", "• "
  if ($s.Length -gt 1500) { $s = $s.Substring(0, 1500).TrimEnd() + "…" }
  return $s
}

Write-Host "Baixando catalogo completo..." -ForegroundColor Cyan
$todos = Get-Produtos "$FORNECEDOR"
Write-Host "  $($todos.Count) produtos encontrados"

$excluidos = @{}
foreach ($h in $EXCLUIR) {
  Write-Host "Excluindo colecao '$h'..." -ForegroundColor Cyan
  foreach ($p in (Get-Produtos "$FORNECEDOR/collections/$h")) { $excluidos[[string]$p.id] = $true }
}
Write-Host "  $($excluidos.Count) produtos excluidos"

$catDe = @{}
foreach ($h in $CATEGORIAS.Keys) {
  Write-Host "Categoria $($CATEGORIAS[$h])..." -ForegroundColor DarkCyan
  foreach ($p in (Get-Produtos "$FORNECEDOR/collections/$h")) {
    $k = [string]$p.id
    if (-not $catDe.ContainsKey($k)) { $catDe[$k] = New-Object System.Collections.ArrayList }
    if (-not $catDe[$k].Contains($CATEGORIAS[$h])) { [void]$catDe[$k].Add($CATEGORIAS[$h]) }
  }
}

$saidaLista = New-Object System.Collections.ArrayList
$esgotados = 0
foreach ($p in $todos) {
  $id = [string]$p.id
  if ($excluidos.ContainsKey($id)) { continue }
  $vars = @($p.variants | ForEach-Object {
    $preco = [math]::Round([decimal]$_.price * $MARGEM, 2)
    $de = 0
    if ($_.compare_at_price -and [decimal]$_.compare_at_price -gt [decimal]$_.price) {
      $de = [math]::Round([decimal]$_.compare_at_price * $MARGEM, 2)
    }
    $img = ""
    if ($_.featured_image) { $img = $_.featured_image.src }
    [ordered]@{ id = [string]$_.id; t = $_.title; p = $preco; de = $de; a = [bool]$_.available; sku = [string]$_.sku; img = $img }
  })
  if ($OCULTAR_ESGOTADOS -and -not ($vars | Where-Object { $_.a })) { $esgotados++; continue }
  $opcao = ""
  if ($p.options -and $p.options.Count -ge 1 -and $p.options[0].name -ne "Title") { $opcao = ($p.options | ForEach-Object { $_.name }) -join " / " }
  $cats = @()
  if ($catDe.ContainsKey($id)) { $cats = @($catDe[$id]) }
  [void]$saidaLista.Add([ordered]@{
    id   = $id
    t    = $p.title
    h    = $p.handle
    c    = $cats
    img  = @($p.images | Select-Object -First 6 | ForEach-Object { $_.src })
    d    = (Convert-Texto $p.body_html)
    o    = $opcao
    v    = $vars
    n    = $p.created_at
  })
}

$json = ConvertTo-Json -InputObject @($saidaLista) -Depth 6 -Compress
$agora = Get-Date -Format "dd/MM/yyyy HH:mm"
$js = "// Gerado automaticamente por atualizar.ps1 em $agora - nao edite manualmente`nwindow.ATUALIZADO_EM = `"$agora`";`nwindow.PRODUTOS = $json;`n"
[System.IO.File]::WriteAllText($saida, $js, (New-Object System.Text.UTF8Encoding($false)))

Write-Host ""
Write-Host "Pronto! $($saidaLista.Count) produtos salvos em loja\produtos.js ($esgotados esgotados ocultos)." -ForegroundColor Green
