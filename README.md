# Digitalizer

Aplicativo Android experimental e independente para fotografar relatórios 5S atuais da Ondexa e conferir a leitura de notas manuscritas de 0 a 5. Versão 0.1.0+1.

## GitHub e Codemagic

1. Crie um repositório GitHub separado do aplicativo Ondexa.
2. Extraia este ZIP e envie o **conteúdo da pasta Digitalizer** à raiz do repositório: `pubspec.yaml`, `codemagic.yaml`, `lib`, `assets`, `test` e `tools` devem estar na raiz.
3. Conecte esse repositório ao Codemagic e escolha o workflow **Digitalizer Android Offline**.
4. O workflow configura o projeto Android incluído, confere os arquivos do modelo, instala dependências, executa análise e testes e gera `Digitalizer.apk`. Se a pasta Android estiver ausente, ele gera o scaffold automaticamente.
5. Baixe o APK em Artifacts e instale no Android. O identificador é `com.ondexa.digitalizer`; não substitui o aplicativo Ondexa.

O Flutter faz o download das dependências durante a compilação. Depois de instalado, o reconhecimento ocorre no aparelho: o modelo de dígitos e o modelo Latin do ML Kit são incorporados ao APK. Não é necessário baixar um modelo no primeiro uso. A permissão de internet é removida do manifesto do aplicativo release.

## Como testar

1. Abra Digitalizer. Opcionalmente selecione a área esperada.
2. Toque em **Fotografar relatório**, ou use uma imagem da galeria para repetir um teste com a mesma folha.
3. Marque os quatro cantos da folha na ordem: superior esquerdo, superior direito, inferior direito e inferior esquerdo. A página é endireitada antes da leitura.
4. Toque em **Ler área e notas**. Confirme a área se estiver diferente ou não for identificada.
5. Se a quantidade/numeração não coincidir com o catálogo atual daquela área, a aplicação é bloqueada. Refaça a foto se o papel estiver correto mas a leitura do texto não estiver completa.
6. Confira cada pergunta e a nota sugerida. Abra **Ampliar folha temporária** para comparar. Campos sem leitura ficam sem nota; zero continua sendo uma nota válida.
7. Corrija manualmente os resultados na tela de revisão e toque em **Concluir teste**. É possível copiar um resumo textual do teste. A foto é descartada ao concluir ou cancelar; nenhum resultado é enviado à Ondexa.

Para testar offline, ative o modo avião antes de abrir Digitalizer, fotografe uma folha atual e verifique se chega à revisão. O aplicativo precisa que uma câmera compatível esteja disponível no aparelho.

Use folha inteira, boa iluminação, foco e pouco desnível. O reconhecimento é conservador: é preferível deixar uma pergunta sem nota a preencher uma nota duvidosa.

## Escopo desta versão

- Catálogo de 32 setores e 749 perguntas, incluindo Showroom com as 14 perguntas aprovadas.
- Leitura da área e dos números das perguntas impressas.
- Última coluna da tabela como coluna de notas atuais, com conferência do cabeçalho MÊS ATUAL quando reconhecido. Resultados por senso e notas anteriores não entram na leitura das notas manuscritas.
- Reconhecimento de dígitos por um modelo MLP embarcado, treinado no MNIST, e rejeição de baixa confiança, dígitos 6–9, células sem tinta, múltiplos componentes relevantes, formatos cortados e leituras instáveis entre três limiares de imagem.
- Revisão temporária, correção manual, ampliação da folha e descarte.

Não há leitura de mês, data, auditor ou outros campos do cabeçalho. Não há banco de auditorias, integração .5s, atualização de auditorias existentes, detecção de duplicidades ou salvamento na Ondexa nesta versão independente. Esses fluxos ficam para a integração posterior, após medir a leitura no aparelho.

## Limites do experimento

Reconhecimento de números manuscritos pode errar mesmo com alta saída do classificador. Os limiares são critérios de rejeição, não uma probabilidade calibrada de acerto em papel. Uma rasura unida ao dígito pode passar pelo filtro; não há garantia de detectar todas as rasuras. **Confira as notas sugeridas**, inclusive as que não ficaram em branco.

O MNIST usa dígitos isolados e limpos; o resultado nesse conjunto não mede o acerto em fotos de relatórios. Métricas e origem do modelo estão em `assets/model_metrics.json`. O modelo não foi treinado com a foto privada enviada pelo usuário. A foto antiga de Leves tem questionário diferente e deve ser recusada pela conferência do catálogo; use uma folha atual para avaliar notas.

Tabelas desfocadas, linhas apagadas, papel dobrado, escrita fora da célula, sombras e OCR incompleto podem impedir a leitura. Esta versão pede marcação manual dos quatro cantos; não faz detecção automática das bordas da página.

A foto fica na memória para conferência. O arquivo de processamento é temporário e removido ao terminar o OCR. O app tenta limpar o cache de captura que criou; não apaga arquivos originais da galeria. Android ou câmera podem manter seu próprio cache temporário. Em encerramento abrupto, o próximo início remove o arquivo de processamento pendente.

## Desenvolvimento

`flutter pub get`, `flutter analyze --no-fatal-infos` e `flutter test` fazem as verificações de código e componentes. Os testes não substituem câmera e ML Kit em aparelho real. Consulte `VALIDACAO.md` para os resultados efetivamente executados. O APK experimental usa assinatura de depuração gerada no ambiente do build; não é uma distribuição de produção da Ondexa.

O modelo já está incluído; não é necessário executar treinamento para compilar. `tools/train_digits.py` permite reproduzir seu treinamento com Python e NumPy. O conjunto MNIST de treinamento não é incluído neste ZIP.

## Referências

- Modelo Latin incorporado: https://developers.google.com/ml-kit/vision/text-recognition/v2/android
- Plugin Flutter: https://pub.dev/packages/google_mlkit_text_recognition
- Captura: https://pub.dev/packages/image_picker
- Dados MNIST: https://keras.io/api/datasets/mnist/
- Fonte e hash oficial dos dados: https://github.com/keras-team/keras/blob/master/keras/src/datasets/mnist.py
