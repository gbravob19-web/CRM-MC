# Conectar el CRM a Supabase

Estos son los únicos pasos manuales — todo lo demás (schema, RLS, realtime, código) ya está listo en el repo.

## 1. Crear el proyecto

1. Entrá a [supabase.com](https://supabase.com) → **New project**.
2. Elegí nombre (ej. `crm-mc-seguros`), contraseña de base de datos, región (recomendado: la más cercana, `South America (São Paulo)`).
3. Esperá ~2 minutos a que se aprovisione.

## 2. Correr el schema

1. En el proyecto, andá a **SQL Editor** → **New query**.
2. Pegá el contenido de [`supabase/schema.sql`](./supabase/schema.sql) y ejecutalo (▶ Run).
3. (Opcional, para tener datos de ejemplo) Repetí el paso con [`supabase/seed.sql`](./supabase/seed.sql).

Esto crea las tablas (`clients`, `policies`, `quotes`, `claims`, `documents`, `notes`, `task_lists`, `tasks`, `task_steps`, `profiles`), activa Row Level Security (cualquier usuario autenticado puede leer/escribir — cartera compartida entre los 4+ brokers) y habilita Realtime.

## 3. Crear las cuentas de los brokers

En **Authentication → Users → Add user** (o **Invite**), creá una cuenta por cada persona del equipo (María Cabrera, Joseph Fonseca, Lucas Herrera, Valentina Ríos, y las que sumes después) con email + contraseña.

Un trigger ya crea automáticamente su fila en `profiles` — por defecto usa el email como nombre. Para poner el nombre e iniciales reales, corré en el SQL Editor (reemplazando el email):

```sql
update profiles set nombre = 'María Cabrera', iniciales = 'MC'
where id = (select id from auth.users where email = 'maria@tuempresa.com');
```

## 4. Conectar la app

1. En el proyecto Supabase: **Settings → API**. Copiá el **Project URL** y la **anon public key**.
2. Abrí `CRM Broker Seguros.dc.html` (y `index.html`, que tiene una copia) y buscá estas dos líneas cerca del principio del `<script>`:

   ```js
   const SUPABASE_URL = 'PENDIENTE_CONFIGURAR';
   const SUPABASE_ANON_KEY = 'PENDIENTE_CONFIGURAR';
   ```

3. Reemplazá los dos valores por los tuyos y guardá.

Con eso, al abrir `index.html` (servido como sitio estático — no funciona con `file://` por las políticas de módulos del navegador, necesita `http://`) vas a ver la pantalla de inicio de sesión. Cada broker entra con su email/contraseña y a partir de ahí todo se guarda y sincroniza en tiempo real entre todos los usuarios conectados.

## Notas

- **Documentos**: por ahora solo se guarda nombre/tipo/fecha (igual que el prototipo original), sin subir el archivo real. Se puede sumar Supabase Storage más adelante si hace falta.
- **Acceso**: el modelo es de cartera compartida — cualquier broker autenticado ve y edita todos los clientes. Si más adelante querés restringir por broker asignado, avisame y ajustamos las políticas de RLS.
