OPENBOX IMPORT - LOJA
=====================

ARQUIVOS
  loja\index.html    -> a loja (abra no navegador)
  loja\config.js     -> seu número de WhatsApp e textos
  loja\produtos.js   -> catálogo (gerado automaticamente, não edite)
  loja\logo.png      -> logo
  atualizar.bat      -> atualiza preços/produtos do fornecedor

1) CONFIGURAR O WHATSAPP
   Abra loja\config.js no Bloco de Notas e preencha:
     whatsapp: "5511987654321"   (55 + DDD + número, só números)

2) ATUALIZAR PREÇOS E PRODUTOS
   Clique duas vezes em atualizar.bat. Leva 1-2 minutos.
   Ele baixa o catálogo do fornecedor, aplica 1,5x, tira a coleção "kits"
   e os esgotados, e regrava loja\produtos.js.
   Para mudar a margem ou excluir mais coleções, edite o topo do atualizar.ps1
   (ex.: $EXCLUIR = @("kits","caixa-fechada")).

3) COLOCAR NO AR
   Envie a pasta "loja" inteira para uma hospedagem de site estático
   (Netlify Drop, GitHub Pages, Hostinger etc.).
   Depois de cada atualização, envie de novo o arquivo produtos.js.

OBS.: o preço do fornecedor NÃO fica salvo na loja - só o seu preço final.
