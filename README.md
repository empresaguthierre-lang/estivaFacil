# EstivaFácil

SaaS/PWA B2B em Rails 8.1 para cubagem, estiva e escolha de veículo por empresa.

## Stack

- Rails 8.1.3
- Ruby 3.4.9
- PostgreSQL com UUID via `pgcrypto`
- Hotwire Turbo/Stimulus com Importmap
- Tailwind CSS v4
- Active Storage
- Solid Queue, Solid Cache e Solid Cable
- Stripe

## Acesso demo

Após preparar o banco e carregar as seeds:

- E-mail: `admin@estivafacil.local`
- Senha: `senha123`

## Configuração local

O arquivo `.env` local carrega as variáveis de ambiente em desenvolvimento. Ele não é versionado.

```powershell
$env:Path="C:\Ruby34-x64\bin;C:\Ruby34-x64\msys64\ucrt64\bin;C:\Ruby34-x64\msys64\usr\bin;C:\Program Files\Git\cmd;$env:Path"
bundle install
bin\rails db:prepare
bin\dev
```

## Usando Supabase

Para usar o Postgres do Supabase, configure `DATABASE_URL` com a connection string do painel em Project Settings > Database.

```powershell
notepad .env
bin\rails db:prepare
```

A chave `anon` pode ser usada no cliente quando houver integração direta com a API do Supabase. A chave `service-role` deve ficar somente no servidor e deve ser rotacionada se tiver sido exposta.

Variáveis úteis:

- `STRIPE_SECRET_KEY`
- `STRIPE_PRICE_ID`
- `DATABASE_URL`
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`

## Escopo inicial

- Multiempresa por `company_id`
- Perfis `admin`, `operador` e `vendedor`
- Cadastro de cargas com itens, cubagem e peso
- Sugestão de veículo ativo por volume e peso
- Plano de estiva inicial com pontuação de ocupação
- Anexo de documento via Active Storage
- Base de assinatura Stripe
