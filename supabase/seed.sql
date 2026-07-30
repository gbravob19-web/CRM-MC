-- Optional demo data — the same 4 sample clients the prototype ships with.
-- Run after schema.sql if you want something to look at right away.
-- Safe to skip entirely; the app works fine starting from an empty database.

with c1 as (
  insert into clients (apellido, nombre, tipo_documento, dni, condicion_fiscal, telefono, email, fecha_nacimiento, direccion, provincia, localidad, codigo_postal)
  values ('Fernández', 'Roberto', 'DNI', '24.556.891', 'Consumidor Final', '11-4455-6677', 'rfernandez@mail.com', '1978-03-14', 'Av. Cabildo 2140, CABA', 'CABA', 'CABA', '1428')
  returning id
), c2 as (
  insert into clients (apellido, nombre, tipo_documento, dni, condicion_fiscal, telefono, email, fecha_nacimiento, direccion, provincia, localidad, codigo_postal)
  values ('Gómez', 'Lucía', 'CUIT', '30-30112447-5', 'Responsable Inscripto', '11-2233-9988', 'lucia.gomez@mail.com', '1990-11-02', 'San Martín 456, Vicente López', 'Buenos Aires', 'Vicente López', '1638')
  returning id
), c3 as (
  insert into clients (apellido, nombre, tipo_documento, dni, condicion_fiscal, telefono, email, fecha_nacimiento, direccion, provincia, localidad, codigo_postal)
  values ('Iturralde', 'Marcelo', 'DNI', '18.774.321', 'Monotributista', '11-6677-1122', 'marcelo.it@mail.com', '1965-07-22', 'Ruta 8 Km 45, Pilar', 'Buenos Aires', 'Pilar', '1629')
  returning id
), c4 as (
  insert into clients (apellido, nombre, tipo_documento, dni, condicion_fiscal, telefono, email, fecha_nacimiento, direccion, provincia, localidad, codigo_postal)
  values ('Suárez', 'Andrea', 'CUIL', '27-27998005-4', 'Consumidor Final', '11-3344-5566', 'andrea.suarez@mail.com', '1984-05-30', 'Belgrano 1200, Rosario', 'Santa Fe', 'Rosario', '2000')
  returning id
),

pol as (
  insert into policies (client_id, type_key, aseguradora, n_poliza, suma_asegurada, prima, vigencia_desde, vigencia_hasta, details)
  select id, 'auto', 'La Segunda', 'AU-4521', 8500000, 42000, '2026-01-10', '2027-01-10',
    '{"marca":"Toyota","modelo":"Corolla","anio":"2022","patente":"AC123DE"}'::jsonb from c1
  union all
  select id, 'inmueble', 'Sancor Seguros', 'IN-9081', 95000000, 68000, '2025-09-01', '2026-08-05',
    '{"direccion":"Av. Cabildo 2140, CABA","tipoInmueble":"Departamento","m2":"75"}'::jsonb from c1
  union all
  select id, 'auto', 'Federación Patronal', 'AU-7712', 6200000, 31000, '2025-08-01', '2026-08-01',
    '{"marca":"Volkswagen","modelo":"Vento","anio":"2021","patente":"AE456FG"}'::jsonb from c2
  union all
  select id, 'negocio', 'Zurich', 'NG-2201', 30000000, 55000, '2026-02-01', '2027-02-01',
    '{"razonSocial":"Gómez Indumentaria SRL","rubro":"Comercio minorista","direccion":"San Martín 456"}'::jsonb from c2
  union all
  select id, 'art', 'Provincia ART', 'ART-330', 0, 24000, '2026-01-01', '2027-01-01',
    '{"razonSocial":"Gómez Indumentaria SRL","cantEmpleados":"6"}'::jsonb from c2
  union all
  select id, 'inmueble', 'La Caja', 'IN-5541', 150000000, 120000, '2025-07-20', '2026-07-28',
    '{"direccion":"Ruta 8 Km 45, Pilar","tipoInmueble":"Casa","m2":"320"}'::jsonb from c3
  union all
  select id, 'vidaSalud', 'Galicia Seguros', 'VS-118', 20000000, 15000, '2026-03-01', '2027-03-01',
    '{"tipoCobertura":"Vida","beneficiarios":"Cónyuge e hijos"}'::jsonb from c3
  union all
  select id, 'caucion', 'Aseguradora de Créditos', 'CA-901', 5000000, 9000, '2025-11-01', '2026-08-10',
    '{"tipoCaucion":"Alquiler comercial","beneficiario":"Inmobiliaria del Norte"}'::jsonb from c3
  union all
  select id, 'auto', 'Mercantil Andina', 'AU-1190', 9800000, 51000, '2026-06-01', '2027-06-01',
    '{"marca":"Ford","modelo":"Territory","anio":"2023","patente":"AF789HI"}'::jsonb from c4
  union all
  select id, 'ap', 'La Segunda', 'AP-410', 10000000, 8000, '2026-01-15', '2026-08-01',
    '{"cobertura":"Muerte e invalidez total"}'::jsonb from c4
  union all
  select id, 'tecnico', 'Sancor Seguros', 'TE-303', 40000000, 33000, '2026-04-01', '2027-04-01',
    '{"tipoEquipo":"Obra en construcción - local comercial"}'::jsonb from c4
  returning 1
),

cq as (
  insert into quotes (client_id, type_key, bien, aseguradora, costo, fecha, estado)
  select id, 'inmueble', 'Inmueble - Casa', 'Sancor Seguros', 112000, '2026-07-18', 'Pendiente' from
    (insert into clients (apellido, nombre, condicion_fiscal, dni)
     values ('Ramos', 'Diego (prospecto)', 'Consumidor Final', '') returning id) as prospecto
  union all
  select id, 'negocio', 'Negocio - Comercio minorista', 'Zurich', 58000, '2026-07-14', 'Pendiente' from c2
  union all
  select id, 'tecnico', 'Seguro técnico - Obra', 'Sancor Seguros', 31000, '2026-07-09', 'Rechazada' from c4
  returning 1
),

sin as (
  insert into claims (client_id, type_key, fecha, estado, descripcion)
  select id, 'auto', '2026-05-12', 'Cerrado', 'Choque leve en cochera, daños en paragolpes.' from c1
  union all
  select id, 'inmueble', '2026-06-30', 'En proceso', 'Filtración de agua por tormenta, daño en techo.' from c3
  returning 1
),

doc as (
  insert into documents (client_id, nombre, tipo, fecha)
  select id, 'DNI frente y dorso', 'DNI', '2026-01-10' from c1
  union all
  select id, 'Escritura propiedad', 'Título', '2025-07-20' from c3
  union all
  select id, 'Foto frente de la casa', 'Foto', '2025-07-20' from c3
  returning 1
),

nt as (
  insert into notes (client_id, author_name, text)
  select id, 'M. Cabrera', 'Cliente prefiere contacto por WhatsApp.' from c1
  union all
  select id, 'M. Cabrera', 'Renovar cotización de vida antes de fin de año.' from c4
  returning 1
),

tl as (
  insert into task_lists (nombre) values ('Mis tareas'), ('Renovaciones')
  returning id, nombre
)

insert into tasks (task_list_id, texto, hecha)
select id, v.texto, v.hecha from tl
join lateral (values
  ('Llamar a Roberto Fernández por renovación', false),
  ('Enviar cotización a Diego Ramos', false),
  ('Actualizar pólizas vencidas', true)
) as v(texto, hecha) on tl.nombre = 'Mis tareas';
