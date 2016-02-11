#!/bin/bash
# Descompacta, edita e compacta o EPUB do ebook do livro
# Expressões Regulares http://www.piazinho.com.br
#
# Testado no OS X (BSD sed), no GNU seria sed -ri '...'
#
# Poderia ser mais eficiente, fazendo um único sed pra não ficar
# regravando todos os arquivos XHTML várias vezes, mas quem se
# importa? Funciona e é rápido mesmo assim :)

# Se der qualquer erro, aborte o script
set -eu

# Recebe o arquivo .pub como argumento de linha de comando
epub="$1"
test -r "$epub" || { echo "Arquivo não encontrado: $epub"; exit 1; }

# Define os nomes e pastas
pasta_epub=$(dirname "$epub")
basename_epub=$(basename "$epub" .epub)
pasta_temp="/tmp/ebook-fix"
epub_final="$pasta_epub/$basename_epub - ARRUMADO.epub"
pasta_fix="$pasta_epub/$basename_epub - ARRUMADO"
pasta_xhtml="$pasta_fix/OEBPS"

# Expande o epub (que é um ZIP) para uma pasta
rm -rf "$pasta_fix"
mkdir "$pasta_fix"
unzip -q "$epub" -d "$pasta_fix"

# Regex para o início de todas as linhas com códigos fonte
regex_base='<p class="[^>]*CodigoFonte[^>]*>'

# Arruma exceção de espaços antes do tab no início da linha
#
# Cap 9 - Java: página 139 (4ed), linha:
#     texto = "0A1B2C3D4E5F";
#
# Como está no HTML:
#
# OEBPS/Miolo_ER_5ed_EPUB_2016_02_04-9.xhtml:
# <p class="_CodigoFontePrimLin1 ParaOverride-6">  &#9;String  texto  = &quot;0A1B2C3D4E5F&quot;;</p>
#
# XXX Arrumar no InDesign
#
sed -E -i '' "s/(${regex_base})  *(&#9;)/\1\2/g" "$pasta_xhtml"/*.xhtml


# Troca tabs no início da linha por espaços (1 tab = 3 espaços)
#
# Afeta Capítulo 9, em: Awk, C, Java, Lua, Perl, PHP PCRE, PHP POSIX, Ruby, Tcl, VBscript
#
# O máximo que achei foram 2 tabs seguidos, no "Cap 9 - C".
# Coloquei o tratamento até 3 tabs seguidos, só pra garantir.
#
# OEBPS/Miolo_ER_5ed_EPUB_2016_02_04-9.xhtml: <p class="_CodigoFonte1 ParaOverride-6">&#9;&#9;error = regexec(&amp;er, argv[2]+start, 1, &amp;match, REG_NOTBOL);</p>
#
# XXX Arrumar no InDesign
#
sed -E -i '' "s/(${regex_base})&#9;&#9;&#9;/\1         /g" "$pasta_xhtml"/*.xhtml
sed -E -i ''     "s/(${regex_base})&#9;&#9;/\1      /g" "$pasta_xhtml"/*.xhtml
sed -E -i ''         "s/(${regex_base})&#9;/\1   /g" "$pasta_xhtml"/*.xhtml


# Neste ponto, não há mais tabs no início das linhas, somente espaços.
# Ainda há tabs no meio das linhas, mas deixemos de lado por enquanto.

sed_script='
    ### Ignorar estas

    # Mais informações são encontradas em:
    /<p class="_CodigoFontePrimLin1[^>]*">http:\/\/aurelio\.net\/regex/ b end

    # Apendice A, Fóruns: lista de URLs
    /<p class="_CodigoFontePrimLin1">http:\/\/groups\.google\.com/ b end
    /<p class="_CodigoFonte1 ParaOverride-6">http:\/\/br\.groups\.yahoo\.com/ b end
    /<p class="_CodigoFonte1 ParaOverride-6">http:\/\/groups\./ b end

    # Apache, tabela de paths
    /<p class="_CodigoFontePrimLin1 ParaOverride-20">&lt;Files &quot;foto.jpg&quot;&gt;<\/p>/ b end
    /<p class="_CodigoFontePrimLin1 ParaOverride-20">&lt;FilesMatch &quot;foto\\.jpg&quot;&gt;<\/p>/ b end
    /<p class="_CodigoFontePrimLin1 ParaOverride-20">[^<]*<span class="_Monoespacado9Negrito _idGenCharOverride-8">/ b end
    /<p class="_CodigoFonte1 ParaOverride-20">[^<]*<span class="_Monoespacado9Negrito _idGenCharOverride-8">/ b end
    /<p class="_CodigoFonte1 ParaOverride-20"> <\/p>/ b end
    /<p class="_CodigoFonte1 ParaOverride-20">\.\.\.<\/p>/ b end

    /_CodigoFonte/ {

        # insere a tag <pre> no início
        i \
<pre>

        # inicia o loop
        :fix
        
            # remove as tags <p> e </p>
            s/^[[:blank:]]*<p [^>]*>//
            s/[[:blank:]]*<\/p>$//
    
            # lê a próxima linha
            n
            
            # continua no loop se for uma linha do bloco
            /_CodigoFonte/ b fix

        # insere a tag </pre> no final
        i \
</pre>

    }

    :end
'

sed -E -i '' "$sed_script" "$pasta_xhtml"/*.xhtml


# Aplica ao PRE as regras do _CodigoFonte1
sed -E -i '' 's/^p._CodigoFonte1 {/pre, &/' "$pasta_xhtml"/css/*

# Remove do PRE as regras do _CodigoFonte1 que não fazem sentido
# Adiciona ao PRE regras para ficar parecido com o original
sed -E -i '' '/^p._CodigoFonte1M {/ i \
pre {\
    text-indent: 0;\
    line-height: 1.5em;\
    margin-left: 14px;\
}\
' "$pasta_xhtml"/css/*


# Remove todas as referências de índice remissivo
# <a id="_idIndexMarker089"></a>
sed -E -i '' 's@<a id="_idIndexMarker[0-9]+"></a>@@g' "$pasta_xhtml"/*.xhtml



# Há 7 linhas com tags <span> no meio do <pre>
# Devem ser apagadas
# XXX Remover no InDesign
#
# $ sed -n '/<pre>/,/<\/pre>/{ /<span/p; }' *.xhtml | grep -v _Symbol
# <span class="_Monoespacado10 _idGenCharOverride-1">^ *[A-Za-z0-9_]+:(.*)$</span>
# <span class="_Monoespacado10 _idGenCharOverride-1">[0-9][0-9]:[0-9][0-9]</span>
# (?&lt;<span class="_Monoespacado10Italico _idGenCharOverride-1">identificador</span>&gt;&lt;<span class="_Monoespacado10Italico _idGenCharOverride-1">conteúdo</span>&gt;)
# <span class="_Monoespacado10 _idGenCharOverride-1">(\()?[0-9]+(?(1)\))</span>
# <span class="_Monoespacado10 _idGenCharOverride-1">[A-Za-z0-9,.()%!]</span>
# <span class="CharOverride-15" xml:lang="en-US">u</span><span class="CharOverride-16" xml:lang="en-US"> GNU/Linux</span>
# <span class="CharOverride-15" xml:lang="en-US">u</span><span class="CharOverride-16" xml:lang="en-US"> BSD/</span><span class="CharOverride-16" xml:lang="en-US"></span><span class="CharOverride-16" xml:lang="en-US">Mac</span>


# Há linhas com tab no meio, pra alinhar os comentários à direita
# Tem que usar espaços, não tabs
# XXX Arrumar no InDesign

# Empacota o epub (cria o arquivo ZIP)
cd "$pasta_fix"
zip -q -r /tmp/ebook-fixed.epub *
cd "$OLDPWD"
mv /tmp/ebook-fixed.epub "$epub_final"

echo "OK. Criado o $epub_final"
