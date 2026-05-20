# Desarrollo y Pruebas Locales de `docker-duckdns`

Este documento describe cómo construir y probar localmente la imagen Docker antes de subir cambios al repositorio y publicar una nueva versión en GitHub Container Registry (GHCR).

---

## 1. Construir la imagen local

Desde la raíz del proyecto, ejecutar:

```bash
docker build -t docker-duckdns:test .
```

Esto genera una imagen local llamada `docker-duckdns:test`.

---

## 2. Crear un archivo `.env`

Crear un archivo llamado `.env` en el mismo directorio con el siguiente contenido:

```env
TZ=America/Costa_Rica
SUBDOMAINS=your_subdomains
TOKEN=tu_token_real
UPDATE_IP=ipv4
USE_INTERNAL_IP=true
```

> **Importante:** Nunca subir este archivo al repositorio. Debe estar incluido en `.gitignore`.

---

## 3. Crear `docker-compose.test.yml`

```yaml
services:
  duckdns:
    image: docker-duckdns:test
    container_name: duckdns-test
    network_mode: host

    env_file:
      - .env

    restart: "no"
```

---

## 4. Levantar el contenedor de prueba

```bash
docker compose -f docker-compose.test.yml up
```

---

## 5. Ver logs en tiempo real

```bash
docker compose -f docker-compose.test.yml logs -f
```

---

## 6. Ejecutar en segundo plano

```bash
docker compose -f docker-compose.test.yml up -d
```

---

## 7. Detener y eliminar el contenedor

```bash
docker compose -f docker-compose.test.yml down
```

---

## 8. Reconstruir después de cambios

Cada vez que se modifique el Dockerfile o los scripts:

```bash
docker build -t docker-duckdns:test .
docker compose -f docker-compose.test.yml up
```

---

## 9. Abrir un shell dentro del contenedor

```bash
docker run --rm -it \
  --entrypoint /bin/sh \
  docker-duckdns:test
```

---

## 10. Inspeccionar ENTRYPOINT y CMD

```bash
docker inspect docker-duckdns:test \
  --format 'Entrypoint: {{json .Config.Entrypoint}} Cmd: {{json .Config.Cmd}}'
```

---

## 11. Ver historial de capas

```bash
docker history docker-duckdns:test
```

---

## 12. Ver labels OCI

```bash
docker inspect docker-duckdns:test \
  --format '{{ json .Config.Labels }}'
```

---

## 13. Flujo de trabajo recomendado

1. Realizar cambios en el código.
2. Construir la imagen local.
3. Probar el contenedor con Docker Compose.
4. Revisar logs y validar funcionamiento.
5. Hacer commit y push al repositorio.
6. GitHub Actions construirá y publicará automáticamente la imagen en GHCR.
7. Actualizar Dokploy para desplegar la nueva versión.

---

## 14. Comandos rápidos

### Construir y ejecutar

```bash
docker build -t docker-duckdns:test .
docker compose -f docker-compose.test.yml up
```

### Limpiar y volver a probar

```bash
docker compose -f docker-compose.test.yml down
docker build -t docker-duckdns:test .
docker compose -f docker-compose.test.yml up
```

### Ejecutar en background

```bash
docker compose -f docker-compose.test.yml up -d
docker compose -f docker-compose.test.yml logs -f
```

---

## 15. Archivos recomendados

```text
.
├── Dockerfile
├── docker-compose.test.yml
├── .env
├── .gitignore
└── root/
```

---

## 16. `.gitignore`

```gitignore
.env
docker-compose.test.yml
```

---

## 17. Buenas prácticas

- Probar siempre localmente antes de hacer `git push`.
- Mantener `.env` fuera del repositorio.
- Revisar logs antes de publicar.
- Usar `restart: "no"` durante las pruebas.
- Publicar versiones etiquetadas además de `latest`.
```
