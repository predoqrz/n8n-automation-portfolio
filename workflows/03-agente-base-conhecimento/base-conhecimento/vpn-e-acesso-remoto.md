# VPN e acesso remoto

> Empresa fictícia (Grupo Aurora), criada para o portfólio. Nenhum procedimento aqui é real.

## Quem tem direito

Todo colaborador com notebook da empresa tem VPN liberada automaticamente no primeiro dia.
Computador pessoal **não** pode se conectar à VPN, sem exceção.

## Instalação

O cliente de VPN é o **FortiClient**, já instalado nos notebooks da empresa. Se não
estiver, instale pelo **Portal da Empresa** (Central de Software), nunca pelo site do
fabricante.

- Servidor: `vpn.grupoaurora.exemplo`
- Usuário: o mesmo do e-mail, sem o domínio
- Segundo fator: código do **Microsoft Authenticator**

## Problemas comuns

- **"Credenciais inválidas"**: a senha de rede expirou. Troque a senha no portal de senhas
  e espere **15 minutos** antes de tentar de novo — é o tempo de sincronização.
- **Conecta e cai em seguida**: rede de hotel ou aeroporto bloqueando VPN. Use o celular
  como roteador.
- **Não recebe o código do Authenticator**: o celular foi trocado. Peça o reset do MFA
  (ver o documento de senhas e MFA).

## Uso fora do país

Viagem internacional exige aviso à TI com **5 dias úteis** de antecedência, por chamado.
Sem aviso, a VPN bloqueia conexões vindas do exterior.
