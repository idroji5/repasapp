-- RepasApp — esquema inicial
--
-- NOTA DE PRIVACIDAD: aquí no hay ninguna tabla de fotos, y es deliberado.
-- Las fotos del cuaderno se procesan en memoria y se descartan al terminar la
-- corrección. De cada foto solo sobrevive el resultado estructurado
-- (qué se escribió mal), nunca la imagen. Ver src/correccion/vision.ts.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------- cuentas ---

create table if not exists padres (
  id            uuid primary key default gen_random_uuid(),
  email         text not null unique,
  password_hash text not null,
  pin_hash      text not null,                  -- PIN de 4 dígitos de la zona de padres
  creado_en     timestamptz not null default now()
);

create table if not exists ninos (
  id             uuid primary key default gen_random_uuid(),
  padre_id       uuid not null references padres(id) on delete cascade,
  nombre         text not null,
  ano_nacimiento smallint,
  -- Curso escolar: 1..6 = Primaria. Reservamos 7..10 para ESO más adelante.
  curso          smallint not null check (curso between 1 and 10),
  minutos_diarios smallint not null default 15 check (minutos_diarios between 5 and 60),
  -- true: la app da pistas antes de la solución. false: va directa a la solución.
  modo_pistas    boolean not null default true,
  creado_en      timestamptz not null default now()
);

create index if not exists ninos_padre_idx on ninos (padre_id);

-- El nivel es independiente por asignatura: un niño puede ir en Matemáticas 4/5
-- y en Dictado 2/5. Esta tabla es la razón por la que edad != dificultad.
create table if not exists niveles_asignatura (
  nino_id        uuid not null references ninos(id) on delete cascade,
  asignatura     text not null,
  nivel          smallint not null default 3 check (nivel between 1 and 5),
  -- Si el padre lo fija a mano, el autoajuste deja de tocarlo.
  bloqueado      boolean not null default false,
  cambiado_en    timestamptz,
  primary key (nino_id, asignatura)
);

-- ------------------------------------------------------------- actividad ---

create table if not exists sesiones (
  id                uuid primary key default gen_random_uuid(),
  nino_id           uuid not null references ninos(id) on delete cascade,
  minutos_previstos smallint not null,
  iniciada_en       timestamptz not null default now(),
  terminada_en      timestamptz
);

create index if not exists sesiones_nino_idx on sesiones (nino_id, iniciada_en desc);

create table if not exists actividades (
  id          uuid primary key default gen_random_uuid(),
  sesion_id   uuid not null references sesiones(id) on delete cascade,
  nino_id     uuid not null references ninos(id) on delete cascade,
  asignatura  text not null,
  nivel       smallint not null,
  orden       smallint not null,
  -- Qué se planteó exactamente: id del dictado, u operaciones generadas con su
  -- semilla. Guardarlo permite reproducir y corregir sin volver a generar.
  contenido   jsonb not null,
  estado      text not null default 'pendiente'
              check (estado in ('pendiente','en_curso','corregida','saltada')),
  aciertos    smallint,
  total       smallint,
  duracion_s  integer,
  creada_en   timestamptz not null default now(),
  corregida_en timestamptz
);

create index if not exists actividades_sesion_idx on actividades (sesion_id, orden);
create index if not exists actividades_nino_idx on actividades (nino_id, creada_en desc);

-- Un registro por error cometido. Es la materia prima del repaso personalizado
-- y de las estadísticas de la zona de padres.
create table if not exists errores (
  id            bigserial primary key,
  nino_id       uuid not null references ninos(id) on delete cascade,
  actividad_id  uuid not null references actividades(id) on delete cascade,
  destreza_id   text not null,
  tipo          text not null,      -- 'tilde', 'b_v', 'resta_con_llevada', ...
  esperado      text not null,
  escrito       text not null,
  creado_en     timestamptz not null default now()
);

create index if not exists errores_nino_idx on errores (nino_id, creado_en desc);
create index if not exists errores_destreza_idx on errores (nino_id, destreza_id);

-- Acumulado por destreza. Redundante con `errores`, pero evita agregaciones
-- caras en cada planificación de sesión.
create table if not exists destrezas_nino (
  nino_id        uuid not null references ninos(id) on delete cascade,
  destreza_id    text not null,
  intentos       integer not null default 0,
  fallos         integer not null default 0,
  ultimo_fallo_en timestamptz,
  primary key (nino_id, destreza_id)
);

-- Historial de cambios de nivel, para que el padre vea por qué subió o bajó.
create table if not exists cambios_nivel (
  id          bigserial primary key,
  nino_id     uuid not null references ninos(id) on delete cascade,
  asignatura  text not null,
  nivel_antes smallint not null,
  nivel_despues smallint not null,
  motivo      text not null,
  creado_en   timestamptz not null default now()
);

create index if not exists cambios_nivel_nino_idx on cambios_nivel (nino_id, creado_en desc);
