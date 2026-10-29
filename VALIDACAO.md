# Revisão 0.1.5+6 — palavras do cabeçalho atual

Única mudança de reconhecimento: localizar MÊS ATUAL pelas caixas dos elementos/palavras OCR, sem utilizar o centro da linha inteira. Aceita o par de palavras vizinhas na mesma linha e etiqueta em um elemento único; ignora MÊS ANT., ATUAL isolado, palavras distantes e elemento que agregue ambos os cabeçalhos. Mantém a primeira localização válida, a conferência existente de coluna, o detector de bordas, a seleção retangular, o catálogo e o reconhecimento das perguntas/notas. A ocorrência isolada da 4.3 não foi alterada por falta do diagnóstico.

Adicionado month_header_test.dart para linha com cabeçalhos anterior/atual juntos, rótulo em um elemento e rejeições. Não executado Flutter localmente por ausência de SDK; Codemagic executará análise e testes antes do build. Scripts de integridade, manifesto e Android conferidos localmente. Teste com a mesma foto no aparelho continua necessário; não há garantia de que esta mudança resolva todas as divergências da coluna.

Atualize todo o repositório com o conteúdo interno de Digitalizer e execute o workflow no novo commit.

## Histórico

# Atualização 0.1.4+5 — seleção retangular por arraste

Única mudança funcional: substituir quatro toques independentes por arrastar uma caixa retangular na foto, em qualquer direção. Os quatro vértices são calculados automaticamente em ordem fixa, limitados à imagem. Novo arraste redefine a caixa e Limpar caixa apaga a seleção. A leitura só é habilitada após soltar o gesto.

Algoritmos de OCR, recuperação de numeração, catálogo, modelo de notas e transformação da imagem permanecem iguais à 0.1.3. O retângulo não corrige por si só uma folha fotografada inclinada.

Verificados scripts de integridade/Android e manifesto dos fontes. Sem SDK Flutter local: análise, testes Flutter e build pelo Codemagic; gesto no celular ainda pendente.

## Histórico

# Revisão 0.1.3+4 — recuperação pelo texto

Recupera os padrões OCR `14`, `44`, `54` e `4.60` somente quando o texto da linha corresponde de forma suficientemente próxima e única à pergunta esperada do catálogo. Exige área identificada unicamente no cabeçalho; sem identificação única, mantém a leitura estrita. Não cria linhas ausentes, não muda a posição da célula, não remove duplicatas e não altera o modelo de notas.

O diagnóstico marca números recuperados pelo texto. Se houver nova falha, envie Copiar diagnóstico. Substitua todo o repositório no GitHub e compile pelo mesmo workflow Codemagic.

Incluídos testes com as quatro linhas OCR reais fornecidas por Felipe, texto incompatível, cabeçalho e correspondência ambígua. Scripts Android e integridade executados localmente; análise Dart e testes Flutter NÃO executados localmente, por ausência do SDK. O workflow executará ambos antes de gerar o APK. Leitura de notas e desempenho no celular ainda dependem do teste físico. Não afirmar reconhecimento perfeito a partir desta recuperação.

## Histórico de revisões

# Validação do Digitalizer

## Revisão 0.1.2+3 — conferência de perguntas

Adicionados relatório de comparação, captura temporária das linhas OCR da margem esquerda e aceitação de número colado ao texto. Dois testes Flutter novos cobrem todas as 25 perguntas de Dobra sem espaço, rejeição de número inválido e detalhamento de ausente/duplicado/inesperado. Não há inferência automática de números ausentes nem liberação de correspondência parcial.

Verificações locais: scripts de integridade do modelo/catálogo e Android aprovados. Flutter/Dart não estão disponíveis nesta máquina; os novos testes e a análise serão executados pelo workflow do Codemagic antes do build. Não houve teste desta revisão no celular, nem reprodução do resultado OCR exato da fotografia, cujas linhas não tinham sido registradas.

## Revisão 0.1.1+2 — diagnóstico em 28/10/2026

O APK anterior foi compilado e instalado pelo usuário. O print enviado registra `PlatformException` com `NullPointerException` na camada nativa durante o processamento OCR. Sem o mapa de ofuscação desse APK, a causa exata permanece não confirmada.

Esta revisão altera o release para `isMinifyEnabled = false` e `isShrinkResources = false`, tanto no Android incluído quanto no script que configura o scaffold no Codemagic. É uma intervenção de diagnóstico para verificar a hipótese de otimização nativa; não comprova por si só que o defeito foi eliminado.

Acrescentado tratamento de `PlatformException` no scanner, mensagem curta na tela e botão Copiar diagnóstico. O erro original é preservado se o encerramento do reconhecedor também falhar. O arquivo de imagem de processamento continua sendo excluído. Não houve alteração do modelo de dígitos, catálogo, critérios de rejeição ou permissão de rede.

Verificações locais desta revisão: `configure_android.py` executado duas vezes com configuração idêntica; `verify_android.py` confirmou release sem minificação e redução de recursos; `verify_assets.py` confirmou 32/749 e hash do modelo. Não houve nova execução de Flutter/análise Dart/build Android nesta revisão local; o SDK isolado da preparação anterior já não está disponível. O workflow repetirá análise e testes antes de compilar. O teste do OCR real depende do próximo APK no celular do usuário.

Os resultados Flutter descritos abaixo são históricos da preparação 0.1.0, não uma nova execução sobre 0.1.1.

## Revisão do build Android — R8

O build do usuário passou pelas verificações Dart e chegou ao `assembleRelease`, mas o R8 interrompeu ao encontrar oito classes opcionais de alfabetos não latinos referenciadas pelo plugin de OCR. A revisão adiciona regras `-dontwarn` limitadas às quatro classes de opções e seus Builders (chinês, devanágari, japonês e coreano), além de ligar o arquivo de regras ao release. O reconhecedor continua usando exclusivamente Latin. A mesma configuração é gerada pelo script quando a pasta Android é recriada no Codemagic.

`tools/verify_android.py` reproduziu a falta da configuração antes da revisão e passou depois dela. A repetição de `configure_android.py` conserva o mesmo resultado. Não houve compilação Android local nesta revisão; a confirmação do R8 e do APK continua no próximo build do Codemagic. Os dez testes Flutter aprovados descritos abaixo são os da preparação original; o código Dart, o modelo e o catálogo não foram alterados nesta revisão.

Preparado em 27/10/2026. Projeto Flutter independente, com Android `com.ondexa.digitalizer`.

## Verificações executadas no computador

- Flutter 3.47.8 estável e Dart 3.13.7, SDK isolado da instalação da Ondexa.
- Dependências resolvidas e registradas em `pubspec.lock`.
- `flutter analyze --no-fatal-infos`: nenhum apontamento após as correções.
- `flutter test`: 10 testes aprovados, incluindo abertura da tela, catálogo, identificação textual de área, bloqueio de numeração incompatível, zero versus ausência de nota, rejeição de dígitos fora da escala, modelo embarcado, células vazias/múltiplos componentes e posição do cabeçalho da coluna atual.
- `python tools/verify_assets.py`: 32 áreas, 749 perguntas e integridade/formato do modelo confirmados.
- Scaffold Android gerado com Flutter e configurado para Android 7/API 24 ou superior, compileSdk 36, identificador independente e manifesto release sem permissão de internet.
- As 32 áreas e suas perguntas vêm do catálogo do Android Ondexa 1.0.12+13 aprovado pelo usuário.

## Modelo de dígitos

MLP 784 → 96 ReLU → 10 classes, com pesos float32 incorporados ao pacote. Treinado no conjunto MNIST oficial, com 60.000 imagens de treino e semente fixa. As 10.000 imagens de teste não participaram das atualizações dos pesos.

Resultado no teste MNIST: 97,97% de acerto entre os dez dígitos e aproximadamente 98,42% no subconjunto de rótulos 0–5. O classificador continua com dez saídas: dígitos 6–9 são rejeitados, em vez de forçados a uma nota válida.

Essas métricas são do conjunto MNIST, sem avaliar sombras, foto de tabela, perspectiva ou rasura. Não representam a taxa de acerto deste aplicativo em relatórios reais. A probabilidade interna não está calibrada para fotos de papel; a tela exige conferência humana de todas as sugestões.

## O que ainda precisa ser validado

Não foi compilado um APK Android local nem executada a câmera/ML Kit em um celular nesta sessão. O workflow do Codemagic executará novamente as verificações e fará o build Android. Testes automatizados Dart não certificam dependências nativas ou leitura óptica no aparelho.

Após instalar pelo Codemagic, testar no modo avião: relatório atual de uma área, coluna atual com e sem comparação, célula vazia, nota zero, todos os dígitos 0–5, rasuras, cabeçalho de área ilegível, área diferente da selecionada, foto fora de foco, cancelamento e conclusão. Comparar as notas sugeridas com as notas reais, registrar correções e campos sem leitura. A foto de Leves antiga enviada pelo usuário é referência visual, não um questionário atual aprovado para importação.

Esta versão não escreve no banco da Ondexa e não altera o aplicativo já instalado. A tela de conferência permite correção temporária e cópia de resumo; não há integração de rascunho, .5s ou duplicidades ainda. A foto não integra evidências fotográficas.
