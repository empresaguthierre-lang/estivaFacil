-- ==========================================
-- SETUP COMPLETO ESTIVAFÁCIL (SCHEMA + SEED)
-- ==========================================

-- ==========================================
-- SCHEMA INICIAL - ESTIVAFÁCIL (NEXT.JS + SUPABASE)
-- Execute este script no SQL Editor do seu painel do Supabase.
-- ==========================================

-- 1. Habilitar extensões necessárias
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. Tabela de Empresas (Multi-tenant)
CREATE TABLE IF NOT EXISTS public.companies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    document TEXT NOT NULL UNIQUE,
    plan TEXT NOT NULL DEFAULT 'essencial', -- 'essencial', 'profissional', 'corporativo'
    status INTEGER NOT NULL DEFAULT 0,       -- 0: Ativo, 1: Suspenso
    stripe_customer_id TEXT UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Habilitar RLS na tabela de empresas
ALTER TABLE public.companies ENABLE ROW LEVEL SECURITY;

-- 3. Perfis de Usuários (Integrado com Supabase Auth)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE RESTRICT,
    name TEXT NOT NULL,
    email TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'vendedor',  -- 'admin', 'operador', 'vendedor'
    active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_company_user_email UNIQUE (company_id, email)
);

-- Habilitar RLS na tabela de perfis
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- 4. Veículos
CREATE TABLE IF NOT EXISTS public.vehicles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    kind TEXT NOT NULL, -- 'VUC', 'Toco', 'Truck', 'Carreta', 'Custom'
    body_type TEXT,    -- 'Baú', 'Sider', 'Grade Baixa', etc.
    length_cm DECIMAL(10, 2) NOT NULL,
    width_cm DECIMAL(10, 2) NOT NULL,
    height_cm DECIMAL(10, 2) NOT NULL,
    max_weight_kg DECIMAL(10, 2) NOT NULL,
    max_volume_m3 DECIMAL(10, 3) NOT NULL,
    pallet_capacity INTEGER,
    usable_length_cm DECIMAL(10, 2),
    usable_width_cm DECIMAL(10, 2),
    usable_height_cm DECIMAL(10, 2),
    allows_hazardous BOOLEAN NOT NULL DEFAULT true,
    refrigerated BOOLEAN NOT NULL DEFAULT false,
    active BOOLEAN NOT NULL DEFAULT true,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_company_vehicle_name UNIQUE (company_id, name)
);

ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;

-- 5. Caixas de Embalagem Padrão
CREATE TABLE IF NOT EXISTS public.package_boxes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    length_cm DECIMAL(10, 2) NOT NULL,
    width_cm DECIMAL(10, 2) NOT NULL,
    height_cm DECIMAL(10, 2) NOT NULL,
    package_weight_kg DECIMAL(10, 2) NOT NULL DEFAULT 0.0,
    units_per_package INTEGER NOT NULL DEFAULT 1,
    active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_company_package_box_name UNIQUE (company_id, name)
);

ALTER TABLE public.package_boxes ENABLE ROW LEVEL SECURITY;

-- 6. Produtos (Catálogo do Cliente)
CREATE TABLE IF NOT EXISTS public.products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    internal_code TEXT NOT NULL, -- Referência interna
    ref_code TEXT,              -- Código de referência comercial (REF da Planilha)
    name TEXT NOT NULL,
    description TEXT,
    active BOOLEAN NOT NULL DEFAULT true,
    sku TEXT,
    unit TEXT NOT NULL DEFAULT 'un',
    
    -- Dimensões e pesos da UNIDADE
    unit_length_cm DECIMAL(10, 2),
    unit_width_cm DECIMAL(10, 2),
    unit_height_cm DECIMAL(10, 2),
    weight_per_unit_kg DECIMAL(10, 3) NOT NULL DEFAULT 0.0,
    
    -- Configurações da CAIXA / EMBALAGEM
    package_box_id UUID REFERENCES public.package_boxes(id) ON DELETE SET NULL,
    package_length_cm DECIMAL(10, 2),
    package_width_cm DECIMAL(10, 2),
    package_height_cm DECIMAL(10, 2),
    package_weight_kg DECIMAL(10, 3),
    units_per_package INTEGER DEFAULT 1,
    package_label TEXT,
    
    -- Multiplicador de volumes (×1 normal, ×2 pote+tampa, ×3 kit, etc.)
    volume_multiplier INTEGER NOT NULL DEFAULT 1,
    
    -- Configurações do PALLET
    packages_per_pallet INTEGER DEFAULT 1,
    pallet_length_cm DECIMAL(10, 2),
    pallet_width_cm DECIMAL(10, 2),
    pallet_height_cm DECIMAL(10, 2),
    pallet_weight_kg DECIMAL(10, 3),
    
    -- Regras de Empilhamento e Estiva
    stackable BOOLEAN NOT NULL DEFAULT true,
    max_stack_layers INTEGER NOT NULL DEFAULT 1,
    can_rotate BOOLEAN NOT NULL DEFAULT true,
    stowage_factor DECIMAL(10, 3) NOT NULL DEFAULT 1.0,
    fragile BOOLEAN NOT NULL DEFAULT false,
    hazardous BOOLEAN NOT NULL DEFAULT false,
    default_count_method TEXT NOT NULL DEFAULT 'unidade', -- 'unidade', 'caixa', 'pallet'
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_company_product_internal_code UNIQUE (company_id, internal_code)
);

CREATE INDEX idx_products_ref_code ON public.products(company_id, ref_code);
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

-- 7. Cargas (Pedidos / Simulações)
CREATE TABLE IF NOT EXISTS public.cargos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    customer_name TEXT NOT NULL,
    origin TEXT NOT NULL,
    destination TEXT NOT NULL,
    recommended_vehicle_id UUID REFERENCES public.vehicles(id) ON DELETE SET NULL,
    status INTEGER NOT NULL DEFAULT 0, -- 0: Planejando, 1: Fechado, 2: Carregado, 3: Entregue
    
    -- Totais Consolidados Calculados
    total_units INTEGER NOT NULL DEFAULT 0,
    total_packages INTEGER NOT NULL DEFAULT 0,
    total_pallets INTEGER NOT NULL DEFAULT 0,
    total_weight_kg DECIMAL(10, 2) NOT NULL DEFAULT 0.0,
    total_volume_m3 DECIMAL(10, 3) NOT NULL DEFAULT 0.0,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.cargos ENABLE ROW LEVEL SECURITY;

-- 8. Itens da Carga
CREATE TABLE IF NOT EXISTS public.cargo_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cargo_id UUID NOT NULL REFERENCES public.cargos(id) ON DELETE CASCADE,
    product_id UUID REFERENCES public.products(id) ON DELETE SET NULL,
    
    -- Snapshots dos dados do produto para manter histórico histórico se o produto mudar
    product_name_snapshot TEXT NOT NULL,
    product_internal_code_snapshot TEXT NOT NULL,
    product_ref_code_snapshot TEXT,
    package_name_snapshot TEXT,
    
    quantity INTEGER NOT NULL DEFAULT 1, -- Quantidade de acordo com o método de contagem
    count_method TEXT NOT NULL DEFAULT 'unidade', -- 'unidade', 'caixa', 'pallet'
    count_quantity DECIMAL(12, 3),
    
    -- Valores calculados deste item na carga
    total_units INTEGER NOT NULL DEFAULT 0,
    total_packages INTEGER NOT NULL DEFAULT 0,
    total_pallets INTEGER NOT NULL DEFAULT 0,
    
    -- Dimensões físicas para o algoritmo de estiva
    length_cm DECIMAL(10, 2) NOT NULL,
    width_cm DECIMAL(10, 2) NOT NULL,
    height_cm DECIMAL(10, 2) NOT NULL,
    weight_kg DECIMAL(10, 2) NOT NULL,
    
    -- Unidade
    units_per_package INTEGER,
    packages_per_pallet INTEGER,
    weight_per_unit_kg DECIMAL(10, 3),
    
    -- Regras físicas
    stackable BOOLEAN NOT NULL DEFAULT true,
    max_stack_layers INTEGER NOT NULL DEFAULT 1,
    can_rotate BOOLEAN NOT NULL DEFAULT true,
    stowage_factor DECIMAL(10, 3),
    fragile BOOLEAN NOT NULL DEFAULT false,
    hazardous BOOLEAN NOT NULL DEFAULT false,
    loading_priority TEXT NOT NULL DEFAULT 'normal', -- 'urgente', 'normal', 'baixa'
    
    -- Resultados de cubagem calculados
    calculated_weight_kg DECIMAL(10, 2) NOT NULL DEFAULT 0.0,
    calculated_volume_m3 DECIMAL(10, 3) NOT NULL DEFAULT 0.0,
    calculated_packages INTEGER NOT NULL DEFAULT 0,
    calculated_pallets INTEGER NOT NULL DEFAULT 0,
    
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.cargo_items ENABLE ROW LEVEL SECURITY;

-- 9. Plano de Estiva (Distribuição de carga tridimensional)
CREATE TABLE IF NOT EXISTS public.stowage_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    cargo_id UUID NOT NULL REFERENCES public.cargos(id) ON DELETE CASCADE,
    vehicle_id UUID NOT NULL REFERENCES public.vehicles(id) ON DELETE RESTRICT,
    status INTEGER NOT NULL DEFAULT 0, -- 0: Rascunho, 1: Validado, 2: Carregado
    score DECIMAL(5, 2) NOT NULL DEFAULT 0.0, -- Nota de eficiência 0 a 100
    volume_usage_percent DECIMAL(6, 2) NOT NULL DEFAULT 0.0,
    weight_usage_percent DECIMAL(6, 2) NOT NULL DEFAULT 0.0,
    
    -- Contadores físicos
    pallet_count INTEGER NOT NULL DEFAULT 0,
    package_count INTEGER NOT NULL DEFAULT 0,
    unit_count INTEGER NOT NULL DEFAULT 0,
    
    -- JSON contendo as posições tridimensionais (x, y, z) de cada caixa/pallet
    loading_sequence TEXT, 
    recommendations TEXT,
    warnings TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.stowage_plans ENABLE ROW LEVEL SECURITY;

-- 10. Assinaturas (Stripe Billing Integration)
CREATE TABLE IF NOT EXISTS public.subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    stripe_subscription_id TEXT UNIQUE,
    stripe_price_id TEXT,
    status TEXT NOT NULL DEFAULT 'trialing', -- 'active', 'trialing', 'canceled', 'past_due'
    current_period_end TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;


-- ==========================================
-- CRIAÇÃO DAS POLÍTICAS RLS (Row Level Security)
-- Isolamento Multi-tenant garantindo que um usuário só vê dados da sua própria empresa (company_id)
-- ==========================================

-- Helper para buscar o company_id do usuário logado via JWT no Supabase Auth.
-- Essa função lê os metadados do profile associado ao ID do Auth.
CREATE OR REPLACE FUNCTION public.get_user_company_id()
RETURNS UUID AS $$
    SELECT company_id FROM public.profiles WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER;

-- Políticas para Companies (Apenas leitura para autenticados da própria empresa)
CREATE POLICY company_select_policy ON public.companies
    FOR SELECT TO authenticated USING (id = public.get_user_company_id());

-- Políticas para Profiles
CREATE POLICY profile_all_policy ON public.profiles
    FOR ALL TO authenticated USING (company_id = public.get_user_company_id());

-- Políticas para Vehicles
CREATE POLICY vehicle_all_policy ON public.vehicles
    FOR ALL TO authenticated USING (company_id = public.get_user_company_id());

-- Políticas para Package Boxes
CREATE POLICY package_box_all_policy ON public.package_boxes
    FOR ALL TO authenticated USING (company_id = public.get_user_company_id());

-- Políticas para Products
CREATE POLICY product_all_policy ON public.products
    FOR ALL TO authenticated USING (company_id = public.get_user_company_id());

-- Políticas para Cargos
CREATE POLICY cargo_all_policy ON public.cargos
    FOR ALL TO authenticated USING (company_id = public.get_user_company_id());

-- Políticas para Cargo Items (Filtra pelo cargo associado que pertence ao company_id)
CREATE POLICY cargo_item_all_policy ON public.cargo_items
    FOR ALL TO authenticated USING (
        EXISTS (
            SELECT 1 FROM public.cargos 
            WHERE cargos.id = cargo_items.cargo_id 
              AND cargos.company_id = public.get_user_company_id()
        )
    );

-- Políticas para Stowage Plans
CREATE POLICY stowage_plan_all_policy ON public.stowage_plans
    FOR ALL TO authenticated USING (company_id = public.get_user_company_id());

-- Políticas para Subscriptions
CREATE POLICY subscription_all_policy ON public.subscriptions
    FOR ALL TO authenticated USING (company_id = public.get_user_company_id());


-- ==========================================
-- SEED DE PRODUTOS E VEÍCULOS
-- ==========================================

-- ==========================================
-- SEED DE DADOS DE TESTE - ESTIVAFÁCIL
-- Importado automaticamente da planilha COTACAO_FRETE_AUTOMATIZADA
-- ==========================================

-- Limpar dados anteriores
DELETE FROM public.cargo_items;
DELETE FROM public.cargos;
DELETE FROM public.stowage_plans;
DELETE FROM public.products;
DELETE FROM public.package_boxes;
DELETE FROM public.vehicles;
DELETE FROM public.profiles;
DELETE FROM public.companies;

-- 1. Inserir Empresa Demo (Grupo Zapala)
INSERT INTO public.companies (id, name, document, plan, status)
VALUES ('d8926947-f495-46bc-9269-e74c8a2b53e3', 'GRUPO ZAPALA', '55.107.481/0001-90', 'profissional', 0);

-- Nota: O Profile precisa estar vinculado a um usuário existente no Supabase Auth.
-- Você pode criar o usuário com ID '11111111-1111-1111-1111-111111111111' ou atualizar este registro após criar o usuário no Auth.
-- INSERT INTO public.profiles (id, company_id, name, email, role, active)
-- VALUES ('11111111-1111-1111-1111-111111111111', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'Guthierre Admin', 'admin@estivafacil.local', 'admin', true);

-- 2. Inserir Veículos Padrão (conforme regras de cubagem e dimensões)
INSERT INTO public.vehicles (id, company_id, name, kind, body_type, length_cm, width_cm, height_cm, max_weight_kg, max_volume_m3, pallet_capacity, usable_length_cm, usable_width_cm, usable_height_cm)
VALUES 
('a1000000-0000-0000-0000-000000000001', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'VUC', 'VUC', 'Baú', 300.00, 220.00, 220.00, 1500.00, 12.000, 4, 290.00, 210.00, 210.00),
('a2000000-0000-0000-0000-000000000002', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'Toco', 'Toco', 'Baú', 650.00, 250.00, 260.00, 6000.00, 32.000, 10, 640.00, 240.00, 250.00),
('a3000000-0000-0000-0000-000000000003', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'Truck', 'Truck', 'Sider', 850.00, 250.00, 280.00, 14000.00, 54.000, 16, 840.00, 245.00, 270.00),
('a4000000-0000-0000-0000-000000000004', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'Carreta', 'Carreta', 'Sider', 1360.00, 250.00, 285.00, 27000.00, 90.000, 28, 1350.00, 245.00, 275.00);

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000001436', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_1436', '1436', 'REL MASTER 30CM MIX', 'Importado do Catálogo', 'un', 0.1, 60.3, 56.5, 31, 2.4000000000000004, 24, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000001437', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_1437', '1437', 'REL SATURNO 27CM MIX', 'Importado do Catálogo', 'un', 0.1, 56.9, 55, 29.4, 2.4000000000000004, 24, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000001439', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_1439', '1439', 'REL EDE 24CM MIX', 'Importado do Catálogo', 'un', 0.1, 50.5, 49.3, 43, 2.4000000000000004, 24, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000000293', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_293', '293', 'REL EDE 24CM TRADICIONAL', 'Importado do Catálogo', 'un', 0.1, 50.5, 49.3, 43, 2.4000000000000004, 24, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000000295', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_295', '295', 'REL EDE 24CM COZINHA', 'Importado do Catálogo', 'un', 0.1, 50.5, 49.3, 43, 2.4000000000000004, 24, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000000298', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_298', '298', 'REL EDE 24CM RELIGIOSO', 'Importado do Catálogo', 'un', 0.1, 50.5, 49.3, 43, 2.4000000000000004, 24, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000000338', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_338', '338', 'REL MASTER 30CM TRADICIONAL', 'Importado do Catálogo', 'un', 0.1, 60.3, 56.5, 31, 2.4000000000000004, 24, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000000340', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_340', '340', 'REL MASTER 30CM COZINHA', 'Importado do Catálogo', 'un', 0.1, 51.3, 43, 22.4, 2.4000000000000004, 24, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000000340', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_340', '340', 'REL MASTER 30CM DECORAÇÃO', 'Importado do Catálogo', 'un', 0.1, 60.3, 56.5, 31, 2.4000000000000004, 24, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000003574', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_3574', '3574', 'REL KAIROS 21CM CX MIX', 'Importado do Catálogo', 'un', 0.1, 51.3, 43, 22.4, 2.4000000000000004, 24, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000000392', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_392', '392', 'REL SATURNO 27CM TRADICIONAL', 'Importado do Catálogo', 'un', 0.1, 56.9, 55, 29.4, 8, 24, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000000394', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_394', '394', 'REL SATURNO 27CM COZINHA', 'Importado do Catálogo', 'un', 0.1, 56.9, 55, 29.4, 8, 24, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000000399', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_399', '399', 'REL SATURNO 27CM RELIGIOSO', 'Importado do Catálogo', 'un', 0.1, 56.9, 55, 29.4, 2.4000000000000004, 24, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000045392', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_45392', '45392', 'COPO CANUDO 700ML GIFT MIX', 'Importado do Catálogo', 'un', 0.1, 60.3, 50.5, 41, 4.7, 20, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000049394', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_49394', '49394', 'COPO CANUDO 700ML A GRANEL MIX', 'Importado do Catálogo', 'un', 0.1, 46, 29.5, 23.5, 1.2000000000000002, 12, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000078908', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_78908', '78908', 'ASSADEIRA ANTIADERENTE C/ FURO NO MEIO P/ BOLO/MANJAR DETALHADA 24X7,8CM - WL6337', 'Importado do Catálogo', 'un', 12, 26.5, 26.5, 21, 12.4, 25, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000074901', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_74901', '74901', 'PROTETOR DE PORTA MIX', 'Importado do Catálogo', 'un', 0.1, 82.9, 41.5, 27.5, 4.800000000000001, 48, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000074979', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_74979', '74979', 'REL KAIROS 21CM CINTA MIX', 'Importado do Catálogo', 'un', 0.1, 47, 42.4, 20.5, 2.4000000000000004, 24, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000075008', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_75008', '75008', 'CAN PORCELANA 280ML MIX', 'Importado do Catálogo', 'un', 0.1, 26, 26, 19, 4.46, 12, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000075916', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_75916', '75916', 'REL KAIROS 21CM CX TRADICIONAL MIX', 'Importado do Catálogo', 'un', 0.1, 47, 42.4, 20.5, 3.5, 24, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000075918', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_75918', '75918', 'REL KAIROS 21CM CX RELIGIOSO MIX', 'Importado do Catálogo', 'un', 0.1, 47, 42.4, 20.5, 3.5, 24, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000075919', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_75919', '75919', 'REL KAIROS 21CM CX CERVEJA MIX', 'Importado do Catálogo', 'un', 0.1, 47, 42.4, 20.5, 3.5, 24, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000075921', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_75921', '75921', 'REL KAIROS 21CM CX COZINHA MIX', 'Importado do Catálogo', 'un', 0.1, 47, 42.4, 20.5, 3.5, 24, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000075946', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_75946', '75946', 'POTE RET. P 380ML CLICK LABEL MIX', 'Importado do Catálogo', 'un', 0, 70, 30, 16, 5.702, 108, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000075947', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_75947', '75947', 'POTE RET. M 740ML CLICK LABEL MIX', 'Importado do Catálogo', 'un', 0, 70, 36, 21, 7.077, 108, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000075948', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_75948', '75948', 'POTE RET. G 1250ML CLICK LABEL MIX', 'Importado do Catálogo', 'un', 0, 1000, 32, 25, 9.56, 108, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000075949', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_75949', '75949', 'POTE RET. 3P 380ML CLICK LABEL MIX', 'Importado do Catálogo', 'un', 0, 70, 30, 16, 5.702, 324, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000075950', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_75950', '75950', 'POTE RET. 3M 740ML CLICK LABEL MIX', 'Importado do Catálogo', 'un', 0, 70, 36, 21, 7.279, 324, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000075951', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_75951', '75951', 'POTE RET. 2G 1250ML CLICK LABEL MIX', 'Importado do Catálogo', 'un', 0, 1000, 32, 25, 9.568, 216, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000075952', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_75952', '75952', 'POTE RET. PMG 380/740/1250ML CLICK LABEL MIX', 'Importado do Catálogo', 'un', 0, 1000, 98, 25, 22.55, 324, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000075860', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_75860', '75860', 'PORTE RET. PMG 380/740/1250ML CLICK CLEAN', 'Importado do Catálogo', 'un', 0, 1000, 98, 25, 22.55, 324, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000075902', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_75902', '75902', 'PORTE RET. PMG 380/740/1250ML CLICK LABEL AQUI TEM AMOR/BCO', 'Importado do Catálogo', 'un', 0, 1000, 98, 25, 22.55, 324, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000075905', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_75905', '75905', 'PORTE RET. PMG 380/740/1250ML CLICK LABEL FLORES/ROSA', 'Importado do Catálogo', 'un', 0, 1000, 98, 25, 22.55, 324, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000075906', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_75906', '75906', 'PORTE RET. PMG 380/740/1250ML CLICK LABEL UTENS/PTO', 'Importado do Catálogo', 'un', 0, 1000, 98, 25, 22.55, 324, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000081926', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_81926', '81926', 'PORTE RET. PMG 380/740/1250ML CLICK LABEL COOK/PTO', 'Importado do Catálogo', 'un', 0, 1000, 98, 25, 22.55, 324, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000076858', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_76858', '76858', 'COQUETELEIRA 700ML A GRANEL MIX', 'Importado do Catálogo', 'un', 0.1, 40.2, 33.5, 28.3, 1.2000000000000002, 12, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000078899', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_78899', '78899', 'FORMA DE PIZZA 36CM', 'Importado do Catálogo', 'un', 8.2, 37, 37, 9.5, 8.5, 25, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000078904', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_78904', '78904', 'FORMA DE PAO 28X15X6CM', 'Importado do Catálogo', 'un', 5.1, 28, 19, 16, 5.4, 25, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000078905', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_78905', '78905', 'ASSADEIRA ANTIADERENTE RET. P/ BOLO 42X28X5CM', 'Importado do Catálogo', 'un', 11.6, 43, 29.8, 13, 11.9, 25, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000078906', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_78906', '78906', 'FORMA ANTIADERENTE P/ 6 CUPCAKES 26X18X2CM', 'Importado do Catálogo', 'un', 4.5, 27, 20, 19, 4.8, 25, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000078907', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_78907', '78907', 'FORMA ANTIADERENTE P/ 12 CUPCAKES 35X26X2CM', 'Importado do Catálogo', 'un', 8.7, 36, 28, 20, 9.1, 25, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000078909', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_78909', '78909', 'ASSADEIRA ANTIADERENTE C/ FURO NO MEIO P/ BOLO/PUDIM 26X11 SEM DETALHE', 'Importado do Catálogo', 'un', 12.6, 27, 27, 24, 13, 25, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000078912', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_78912', '78912', 'KIT 3 PÇS FORMA ANTIADERENTE RED. COM FUNDO REMOVÍVEL', 'Importado do Catálogo', 'un', 7.6, 58, 43, 29, 8.1, 12, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000078913', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_78913', '78913', 'ASSADEIRA ANTIADERENTE REDONDA P/ BOLO 28X4,5CM', 'Importado do Catálogo', 'un', 4.5, 26.5, 26.5, 14.5, 5, 25, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000078973', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_78973', '78973', 'PROCESSADOR DE ACRÍLICO 500ML 13X10CM MIX', 'Importado do Catálogo', 'un', 7.7, 62, 41, 28, 8.7, 36, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000078982', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_78982', '78982', 'CONCHA DE SILICONE/INOX 30X8.5CM MIX VERM/PTO', 'Importado do Catálogo', 'un', 12.6, 51, 46, 38, 14, 144, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000078983', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_78983', '78983', 'ESPATULA DE SILICONE/INOX 34.5X8CM MIX VERM/PTO', 'Importado do Catálogo', 'un', 8.7, 41, 41, 41, 9.1, 25, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000083805', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_83805', '83805', 'CJ UTENSILIOS DE COZINHA SILICONE C/ CABO MADEIRA 7 UNI - PRETO', 'Importado do Catálogo', 'un', 6.4, 44, 34, 32.5, 7.4, 12, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000078984', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_78984', '78984', 'COLHER DE SILICONE/INOX 33X6CM', 'Importado do Catálogo', 'un', 10.9, 44, 41, 41, 14, 144, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000078985', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_78985', '78985', 'ESCUMADEIRA DE SILICONE/INOX 32X10CM MIX VERM/PTO', 'Importado do Catálogo', 'un', 14.3, 44, 41, 41, 15.8, 144, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000078986', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_78986', '78986', 'PEGADOR MASSA DE SILICONE/INOX 32X7CM MIX VERM/PTO', 'Importado do Catálogo', 'un', 14, 54.5, 38, 28, 16, 144, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000078987', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_78987', '78987', 'CONCHA DE SILICONE 28.5X8.2CM MIX VERM/PTO', 'Importado do Catálogo', 'un', 13.9, 50, 37.5, 30.5, 12.9, 144, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000078988', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_78988', '78988', 'ESCUMADEIRA DE SILICONE 28.5X8.3CM MIX VERM/PTO', 'Importado do Catálogo', 'un', 10.3, 53, 35, 32.5, 10.9, 144, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000078990', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_78990', '78990', 'PEGADOR MASSA DE SILICONE 28.5X5CM MIX VERM/PTO', 'Importado do Catálogo', 'un', 9.2, 44.5, 38.5, 35.5, 9.9, 144, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000078991', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_78991', '78991', 'ESPATULA VAZADA SILICONE 29.5X8CM MIX VERM/PTO', 'Importado do Catálogo', 'un', 12.9, 50, 35.5, 28.5, 13.9, 144, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000078992', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_78992', '78992', 'ESPATULA RETA DE SILICONE 27.5X5.5CM MIX VERM/PTO', 'Importado do Catálogo', 'un', 11.8, 44, 33.5, 28.5, 12.8, 144, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000078993', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_78993', '78993', 'RALADOR DE INOX 6 FACES 9''''', 'Importado do Catálogo', 'un', 13, 79.5, 35, 31, 14.5, 72, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000078994', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_78994', '78994', 'RALADOR DE INOX 4 FACES 9''''', 'Importado do Catálogo', 'un', 21, 84, 42.5, 31.5, 22, 144, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000081700', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_81700', '81700', 'JOGO DE COLHERES INOX C/ 6 PÇS', 'Importado do Catálogo', 'un', 11.1, 26, 18, 11, 11.4, 48, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000081701', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_81701', '81701', 'JOGO DE GARFOS INOX C/ 6 PÇS', 'Importado do Catálogo', 'un', 8.5, 26, 18, 11, 8.8, 48, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000081702', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_81702', '81702', 'JOGO DE FACAS INOX C/ 6 PÇS', 'Importado do Catálogo', 'un', 11.4, 28, 18, 11, 11.7, 48, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000081703', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_81703', '81703', 'JOGO DE COLHERES SOBREMESA INOX C/ 6 PÇS', 'Importado do Catálogo', 'un', 10.7, 25, 19, 10, 11.1, 60, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000081704', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_81704', '81704', 'JOGO DE GARFOS SOBREMESA INOX C/ 6 PÇS', 'Importado do Catálogo', 'un', 7.4, 25, 19, 10, 7.8, 60, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000081705', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_81705', '81705', 'JOGO DE FACAS SOBREMESA INOX C/ 6 PÇS', 'Importado do Catálogo', 'un', 10.7, 25, 19, 10, 11.1, 60, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000081856', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_81856', '81856', 'RALO DE PIA INOX 7CM', 'Importado do Catálogo', 'un', 7, 54, 21, 21, 8, 480, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000081859', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_81859', '81859', 'PORTA SABONETE LIQUIDO DE VIDRO 17,5CM', 'Importado do Catálogo', 'un', 12.7, 49, 40, 33, 13.7, 48, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000081860', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_81860', '81860', 'KIT 2 PCS FACA 32CM E CHAIRA 30CM INOX', 'Importado do Catálogo', 'un', 26, 48.5, 41.5, 41.5, 27, 96, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000081861', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_81861', '81861', 'KIT 3 PCS FACA CHAIRA E GARFO 30CM INOX', 'Importado do Catálogo', 'un', 25, 57, 51, 40, 26.5, 96, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000081864', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_81864', '81864', 'FORMA DE SILICONE REDONDA 24X5CM', 'Importado do Catálogo', 'un', 5.85, 38, 26, 26, 6.25, 48, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000081865', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_81865', '81865', 'LUVA BICO P/ COZINHA DE SILICONE 11X8,5X7,5CM', 'Importado do Catálogo', 'un', 1.7, 28, 21, 17, 1.9, 60, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000081866', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_81866', '81866', 'DESCANSO DE PANELA REDONDO SILICONE 18CM', 'Importado do Catálogo', 'un', 7.2, 45, 40, 20, 7.8, 144, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000081867', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_81867', '81867', 'BATEDOR/FOUET SILICONE 25CM', 'Importado do Catálogo', 'un', 1, 26.5, 21, 20, 1.4, 36, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000082400', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_82400', '82400', 'RELÓGIO DE PAREDE 25CM MIX', 'Importado do Catálogo', 'un', 20, 60, 54, 54, 21.7, 100, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000082402', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_82402', '82402', 'SQUEEZE DE PLÁSTICO 800ML 25X7CM MIX MOD. 1', 'Importado do Catálogo', 'un', 7.3, 60, 52, 38, 8.7, 80, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000082403', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_82403', '82403', 'SQUEEZE DE PLÁSTICO 800ML 25X7CM MIX MOD. 2', 'Importado do Catálogo', 'un', 7.3, 60, 52, 38, 8.7, 80, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000082404', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_82404', '82404', 'SQUEEZE DE PLÁSTICO 700ML 24.5X7.5CM MIX', 'Importado do Catálogo', 'un', 7.3, 60, 52, 38, 8.7, 80, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000082405', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_82405', '82405', 'SQUEEZE DE PLÁSTICO 700ML 24.2X7.5CM MIX', 'Importado do Catálogo', 'un', 7.3, 60, 52, 38, 8.7, 80, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000082406', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_82406', '82406', 'SQUEEZE DE PLÁSTICO 700ML 23.2X7.5CM MIX', 'Importado do Catálogo', 'un', 7.3, 60, 52, 38, 8.7, 80, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000082408', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_82408', '82408', 'SQUEEZE DE PLÁSTICO 800ML 25.5X7.2CM MIX', 'Importado do Catálogo', 'un', 0.1, 39.4, 26.5, 26.5, 0.1, 1, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000082409', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_82409', '82409', 'SQUEEZE DE PLÁSTICO 1500ML 29X9,5CM MIX', 'Importado do Catálogo', 'un', 0.1, 39.4, 26.5, 26.5, 0.1, 1, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000082410', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_82410', '82410', 'SQUEEZE DE PLÁSTICO 700ML 24.2X7.2CM MIX', 'Importado do Catálogo', 'un', 7.3, 60, 52, 38, 8.7, 80, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000082412', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_82412', '82412', 'SQUEEZE DE PLÁSTICO 800ML 25.3X7CM MIX', 'Importado do Catálogo', 'un', 7.3, 60, 52, 38, 8.7, 80, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000082413', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_82413', '82413', 'SQUEEZE DE PLÁSTICO 900ML 26X8,8CM MIX', 'Importado do Catálogo', 'un', 0.1, 39.4, 26.5, 26.5, 0.1, 1, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000082417', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_82417', '82417', 'TAPETE POLIESTER 35X59CM BASE TNT', 'Importado do Catálogo', 'un', 8, 61, 41, 25, 9, 60, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000082421', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_82421', '82421', 'TAPETE BOX 63X33CM PVC', 'Importado do Catálogo', 'un', 11.5, 68, 35, 13, 11.8, 36, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000082422', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_82422', '82422', 'TAPETE BOX 63X33CM PVC BOLHAS', 'Importado do Catálogo', 'un', 11.5, 68, 35, 13, 11.8, 36, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000082425', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_82425', '82425', 'RELÓGIO DE PAREDE ALUM. 35CM', 'Importado do Catálogo', 'un', 9.6, 68.5, 41, 38, 11, 12, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000082428', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_82428', '82428', 'RELÓGIO DE PAREDE ALUM. PRATA 35CM', 'Importado do Catálogo', 'un', 9.6, 68.5, 41, 38, 11, 12, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000082436', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_82436', '82436', 'BATEDOR FOUET INOX 29X7CM', 'Importado do Catálogo', 'un', 1.1, 34, 26, 21, 1.4, 24, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000082437', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_82437', '82437', 'PENEIRA INOX 20,5X8CM', 'Importado do Catálogo', 'un', 13, 44, 29, 23, 15, 500, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000082440', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_82440', '82440', 'ESCORREDOR DE MACARRÃO INOX 26X10CM', 'Importado do Catálogo', 'un', 20, 60, 54, 54, 21.7, 100, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000082442', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_82442', '82442', 'BACIA DE COZINHA INOX 17,8X9CM', 'Importado do Catálogo', 'un', 17.2, 56, 37, 37, 18.2, 160, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000082445', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_82445', '82445', 'BACIA DE COZINHA INOX 26X12CM', 'Importado do Catálogo', 'un', 20.3, 53, 53, 51, 21.3, 100, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000082446', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_82446', '82446', 'TIGELA PARA SALADA INOX 22CM', 'Importado do Catálogo', 'un', 19, 48, 45, 45, 20.5, 120, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000082449', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_82449', '82449', 'TIGELA PARA SALADA INOX 28CM', 'Importado do Catálogo', 'un', 22, 57, 57, 47, 24.3, 80, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000082451', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_82451', '82451', 'TRAVESSA INOX 25CM', 'Importado do Catálogo', 'un', 22.5, 50, 32, 27, 23.4, 300, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000082453', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_82453', '82453', 'TRAVESSA INOX 35CM', 'Importado do Catálogo', 'un', 31, 43, 36, 36, 32.2, 200, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000082463', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_82463', '82463', 'KIT 6 PÇS TAMPA DE SILICONE', 'Importado do Catálogo', 'un', 16.5, 42, 42, 42, 16, 200, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000082464', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_82464', '82464', 'DESCASCADOR DE FRUTAS E LEGUMES 18X2.5CM PLÁSTICO/INOX', 'Importado do Catálogo', 'un', 17.4, 49, 46, 38, 19.7, 350, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000082468', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_82468', '82468', 'SACA ROLHAS 16X6CM LIGA DE ZINCO', 'Importado do Catálogo', 'un', 13.5, 50, 38, 33, 15, 150, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000082473', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_82473', '82473', 'COLHER MEDIDORA 4 PÇS 5-9CM PLASTICO/INOX', 'Importado do Catálogo', 'un', 17.5, 57, 49, 38.5, 18.5, 144, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000082478', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_82478', '82478', 'PORTA TEMPERO VIDRO/INOX 90ML 8X4,9CM', 'Importado do Catálogo', 'un', 18, 44, 33, 30, 20, 144, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000082481', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_82481', '82481', 'AÇUCAREIRO DE INOX 300ML 8,5CM', 'Importado do Catálogo', 'un', 16, 72, 50, 43, 19.5, 240, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000082494', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_82494', '82494', 'BALANÇA DIGITAL DE COZINHA 10 KG', 'Importado do Catálogo', 'un', 11.5, 47.5, 45, 35.5, 12, 40, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000082495', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_82495', '82495', 'RALADOR 26X9,5X6,6CM', 'Importado do Catálogo', 'un', 0.1, 57, 49, 44, 36, 360, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000082496', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_82496', '82496', 'RALADOR E FATIADOR 23,2X17,5X6,5CM', 'Importado do Catálogo', 'un', 21, 54, 51, 43, 22, 120, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000082497', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_82497', '82497', 'RALADOR 27X11,5X4,5CM', 'Importado do Catálogo', 'un', 26, 84, 70, 60, 28, 240, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000082499', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_82499', '82499', 'TESOURA S/ PONTA 14CM', 'Importado do Catálogo', 'un', 19, 45, 40, 40, 20, 600, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000082542', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_82542', '82542', 'CHALEIRA ELETRICA INOX 1,8L - 127V', 'Importado do Catálogo', 'un', 7.32, 62, 47.5, 34, 8.8, 12, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000082543', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_82543', '82543', 'CHALEIRA ELETRICA INOX 1,8L - 220V', 'Importado do Catálogo', 'un', 0, 62, 47.5, 34, 8.8, 12, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000082796', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_82796', '82796', 'ASSADEIRA ANTIADERENTE RET. P/ BOLO 32X22X5CM', 'Importado do Catálogo', 'un', 7.1, 33, 23, 16, 7.4, 25, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000083816', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_83816', '83816', 'PORTA COND GIRAT  QUAD EM INOX  12 PTS VD  - BV7324 - PMT', 'Importado do Catálogo', 'un', 7.1, 42, 36.5, 19, 7.9, 4, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000083817', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_83817', '83817', 'PORTA COND GIRAT  QUAD EM INOX  16 PTS VD', 'Importado do Catálogo', 'un', 8.8, 53, 36.7, 19, 9.2, 4, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000083820', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_83820', '83820', 'PORTA COND GIRAT 12 PTS VD TP AJUSTAVEL', 'Importado do Catálogo', 'un', 6.2, 42.5, 36.5, 19, 7, 4, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000083821', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_83821', '83821', 'PORTA COND GIRAT 6 PTS VD TP AJUSTAVEL', 'Importado do Catálogo', 'un', 4.7, 47, 36.5, 19, 5.6, 6, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000083822', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_83822', '83822', 'PORTA COND GIRAT 9 PTS VD TP AJUSTAVEL', 'Importado do Catálogo', 'un', 4.6, 43, 36.5, 19, 5.1, 4, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000083827', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_83827', '83827', 'SIL CB INOX BATEDOR 30CM - PT - BK4483SK - PMT', 'Importado do Catálogo', 'un', 1.1, 34, 26, 21, 1.4, 24, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000083828', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_83828', '83828', 'SIL CB INOX BATEDOR 30CM - VM - BK4482SK - PMT', 'Importado do Catálogo', 'un', 1.1, 34, 26, 21, 1.4, 24, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000083847', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_83847', '83847', 'CJ XICARAS C/ BASE E ALÇA EM INOX  - ANNE C/ 6 - 230 ML', 'Importado do Catálogo', 'un', 7.9, 46, 33.6, 21.5, 8.9, 6, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000083863', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_83863', '83863', 'VD POTE VIDRO CANEL RET 370ML - BRANCO - BV5200 - PMT', 'Importado do Catálogo', 'un', 3.8, 49.2, 24.8, 13.6, 5, 12, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000083864', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_83864', '83864', 'VD POTE VIDRO CANEL RET 370ML VERM - BV5201 - PMT', 'Importado do Catálogo', 'un', 3.8, 49.2, 24.8, 13.6, 5, 12, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000083865', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_83865', '83865', 'VD POTE VIDRO DIAM RET 370ML - BRANCO', 'Importado do Catálogo', 'un', 3.8, 49.2, 24.8, 13.6, 5, 12, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000083867', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_83867', '83867', 'VD POTE VIDRO RET 640ML - BRANCO', 'Importado do Catálogo', 'un', 5.4, 38.5, 29, 21, 6.8, 12, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000083869', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_83869', '83869', 'VD POTE VIDRO RET 1520ML - AZUL', 'Importado do Catálogo', 'un', 0, 55, 33, 24.7, 12.4, 12, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000083874', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_83874', '83874', 'VD POTE VIDRO RET 1520ML VERM', 'Importado do Catálogo', 'un', 0, 55, 33, 24.7, 12.4, 12, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000083876', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_83876', '83876', 'VD POTE VIDRO RET 180ML - SIL AZUL', 'Importado do Catálogo', 'un', 3.8, 49.2, 24.8, 13.6, 5, 12, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000083877', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_83877', '83877', 'VD POTE VIDRO RET 180ML SIL VERM', 'Importado do Catálogo', 'un', 3.8, 49.2, 24.8, 13.6, 5, 12, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000083878', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_83878', '83878', 'ESCOVA SANITARIA C/ SUP - PRETO/BRANCO - KC5980 - PMT', 'Importado do Catálogo', 'un', 0, 45, 33, 23.5, 4.4, 12, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000083914', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_83914', '83914', 'PANO MULTIUSO MICROFIBRA 25X25 CM - KC7896 - PMT', 'Importado do Catálogo', 'un', 4.4, 32.5, 32.5, 26.5, 4.8, 16, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000083916', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_83916', '83916', 'VD POTE VIDRO CANEL RET 640ML -VERM', 'Importado do Catálogo', 'un', 5.4, 38.5, 29, 21, 6.8, 12, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000083926', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_83926', '83926', 'KIT DE BANHEIRO 2 PEÇAS VIDRO COM DISPENSER 400ML PORTA ESCOVA', 'Importado do Catálogo', 'un', 10, 63, 41, 26, 11, 36, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000084328', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_84328', '84328', 'PORTA COND GIRAT  QUAD EM INOX  12 PTS VD', 'Importado do Catálogo', 'un', 5.3, 42, 36.5, 19, 6.1, 4, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;

INSERT INTO public.products (id, company_id, internal_code, ref_code, name, description, unit, weight_per_unit_kg, package_length_cm, package_width_cm, package_height_cm, package_weight_kg, units_per_package, active) 
VALUES ('f0000000-0000-0000-0000-000000083545', 'd8926947-f495-46bc-9269-e74c8a2b53e3', 'REF_83545', '83545', 'POTE RET. 4G 1250ML CLICK LABEL MIX', 'Importado do Catálogo', 'un', 0, 1000, 32, 25, 0, 432, true) 
ON CONFLICT (company_id, internal_code) DO UPDATE SET name = EXCLUDED.name, package_length_cm = EXCLUDED.package_length_cm, package_width_cm = EXCLUDED.package_width_cm, package_height_cm = EXCLUDED.package_height_cm, package_weight_kg = EXCLUDED.package_weight_kg;


