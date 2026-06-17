import { createClient } from '@supabase/supabase-js'
import fs from 'node:fs/promises'
import path from 'node:path'

const projectRoot = '.'

function parseEnv(contents) {
  return Object.fromEntries(
    contents
      .split(/\r?\n/)
      .map((line) => line.trim())
      .filter((line) => line && !line.startsWith('#') && line.includes('='))
      .map((line) => {
        const index = line.indexOf('=')
        return [line.slice(0, index), line.slice(index + 1)]
      }),
  )
}

async function main() {
  const envContent = await fs.readFile(path.join(projectRoot, '.env.local'), 'utf8')
  const env = parseEnv(envContent)
  
  const url = env.NEXT_PUBLIC_SUPABASE_URL
  const serviceKey = env.SUPABASE_SERVICE_ROLE_KEY

  if (!url || !serviceKey) {
    console.error('URL ou serviceKey ausente em .env.local')
    return
  }

  const supabase = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false }
  })

  const email = 'admin@estivafacil.com'
  const password = 'Senha123!'
  const companyId = 'd8926947-f495-46bc-9269-e74c8a2b53e3'

  console.log(`Criando usuário de autenticação: ${email} ...`)
  
  // 1. Create auth user
  const { data: userData, error: userError } = await supabase.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { nome: 'Admin EstivaFácil' },
    app_metadata: { role: 'admin' }
  })

  let userId = ''

  if (userError) {
    if (userError.message.includes('already exists') || userError.message.includes('already registered')) {
      console.log('Usuário já cadastrado no Auth. Buscando ID...')
      const { data: listData, error: listError } = await supabase.auth.admin.listUsers()
      if (listError) {
        console.error('Erro ao buscar usuários:', listError.message)
        return
      }
      const existing = listData.users.find(u => u.email === email)
      if (existing) {
        userId = existing.id
        console.log('ID encontrado:', userId)
      } else {
        console.error('Usuário não encontrado na listagem.')
        return
      }
    } else {
      console.error('Erro ao criar usuário Auth:', userError.message)
      return
    }
  } else {
    userId = userData.user.id
    console.log('Usuário Auth criado com sucesso! ID:', userId)
  }

  // 2. Try inserting profile
  console.log(`Inserindo perfil na tabela public.profiles para a empresa ID ${companyId}...`)
  
  // Ensure the company exists
  const { error: compError } = await supabase
    .from('companies')
    .insert({
      id: companyId,
      name: 'GRUPO ZAPALA',
      document: '55.107.481/0001-90',
      plan: 'profissional',
      status: 0
    })
    .select('id')
    .single()

  if (compError && !compError.message.includes('duplicate key')) {
    console.warn('Nota (Empresa):', compError.message)
  }

  const { error: profileError } = await supabase
    .from('profiles')
    .insert({
      id: userId,
      company_id: companyId,
      name: 'Admin EstivaFácil',
      email: email,
      role: 'admin',
      active: true
    })

  if (profileError) {
    if (profileError.message.includes('duplicate key')) {
      console.log('Perfil já existente na tabela profiles.')
    } else {
      console.error('Erro ao inserir perfil (verifique se rodou a migração SQL do schema antes):', profileError.message)
    }
  } else {
    console.log('Perfil criado com sucesso na tabela public.profiles!')
  }

  console.log('\n--- CREDENCIAIS DE ACESSO ---')
  console.log(`E-mail: ${email}`)
  console.log(`Senha: ${password}`)
  console.log('----------------------------')
}

main().catch(console.error)
