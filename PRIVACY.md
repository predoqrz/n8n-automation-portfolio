# Política de privacidade — n8n portfólio

Última atualização: 16 de setembro de 2026

Este documento descreve como o app **n8n portfólio** trata dados da conta Google que o
autoriza. O app é um projeto pessoal de portfólio, roda em uma instância self-hosted do
n8n e é usado apenas pelo próprio autor, na própria conta.

## Quais dados são acessados

O app acessa o Gmail da conta autorizada, e somente para:

- **ler** e-mails que tenham o marcador `Chamados` e ainda não tenham o marcador
  `Chamado processado`: remetente, assunto, data e corpo da mensagem;
- **aplicar** o marcador `Chamado processado` depois que o e-mail é tratado;
- **listar** os marcadores da conta, para localizar o marcador acima.

O app não envia e-mails, não apaga mensagens e não lê e-mails fora desse marcador.

## Para onde os dados vão

| Destino | O que recebe | Para quê |
|---|---|---|
| OpenAI (API) | assunto, remetente, data e até 1.900 caracteres do corpo | classificar o chamado em categoria, urgência e resumo |
| Notion (workspace do autor) | os mesmos campos e a classificação | registrar o chamado para atendimento |
| PostgreSQL local | identificadores, assunto, classificação e resultado | log de execução e prevenção de duplicidade |

Os dados não são vendidos, compartilhados com terceiros além dos listados acima, nem
usados para publicidade.

## Uso de dados do Google

O uso e a transferência de informações recebidas das APIs do Google seguem a
[Política de dados do usuário dos serviços de API do Google](https://developers.google.com/terms/api-services-user-data-policy),
incluindo os requisitos de uso limitado.

## Armazenamento e exclusão

Credenciais de acesso ficam criptografadas na instância local do n8n. Para revogar o
acesso a qualquer momento, acesse
[myaccount.google.com/permissions](https://myaccount.google.com/permissions) e remova o
app **n8n portfólio**. Registros no Notion e no banco local podem ser apagados pelo
autor a qualquer momento.

## Contato

Dúvidas: abra uma issue em
[github.com/predoqrz/n8n-automation-portfolio](https://github.com/predoqrz/n8n-automation-portfolio/issues).
