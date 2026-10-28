# Validação do Digitalizer 0.1.0+1

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
