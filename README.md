# demo-c4: de la laptop a una VM, a mano y con dos pipelines

Una API chica (FastAPI) que se empaqueta con Docker, se prueba en local, se sube a
Artifact Registry y corre en una VM de GCP con `docker pull`. Después, lo mismo lo
hacen dos pipelines de GitHub Actions, sin ninguna clave guardada (OIDC).

```
app/                     la API, sus tests y su Dockerfile
infra/                   OpenTofu: UNA VM con Docker + firewall 8080 y 22 + SSH con clave propia
.github/workflows/
  infra.yml              pipeline de la MÁQUINA: tofu plan (PR) / plan + apply (main)
  app.yml                pipeline de la APP: test -> build + push -> deploy (docker pull en la VM)
```

¿Por qué dos pipelines? Cambian a ritmos distintos (la app muchas veces por día, la
máquina casi nunca) y necesitan permisos distintos: el que publica la app no puede
borrar la VM, y el que crea la VM no puede publicar imágenes. Cada uno tiene su propia
service account; los dos entran con el mismo provider de OIDC.

Variables de ejemplo (proyecto de la cátedra):

```bash
export PROJECT_ID=project-4c4f803f-f2a7-4566-9fe REGION=us-central1 ZONE=us-central1-a
export AR=us-central1-docker.pkg.dev/$PROJECT_ID/infra-cloud-template
```

## 1. La API, en la laptop

```bash
cd app
uv run --python 3.12 --with-requirements requirements.txt --with pytest --with httpx pytest -q
uv run --python 3.12 --with-requirements requirements.txt uvicorn main:app --port 18401
```

Navegador: <http://localhost:18401/> y <http://localhost:18401/docs>. Con curl:

```bash
curl -s localhost:18401/
curl -s -X POST localhost:18401/items -H 'Content-Type: application/json' -d '{"nombre":"local"}'
curl -s localhost:18401/items
```

## 2. La misma API, en un contenedor

```bash
docker build -t demo-c4:dev ./app
docker run -d --name demo-c4 -p 18402:8080 -v demo-c4-data:/data demo-c4:dev
curl -s localhost:18402/                       # "host" ahora es el id del contenedor
docker rm -f demo-c4                           # se va el contenedor...
docker run -d --name demo-c4 -p 18402:8080 -v demo-c4-data:/data demo-c4:dev
curl -s localhost:18402/items                  # ...el dato queda en el volumen
```

## 3. Subir la imagen a Artifact Registry

```bash
gcloud auth configure-docker us-central1-docker.pkg.dev --quiet
docker tag demo-c4:dev $AR/demo-c4:v1
docker push $AR/demo-c4:v1
gcloud artifacts docker images list $AR --include-tags
```

## 4. La VM hace `docker pull`

Una clave SSH propia (la pública va a la VM; la privada queda en tu laptop):

```bash
ssh-keygen -t ed25519 -f ~/.ssh/clase4 -N "" -C clase4
```

A mano (lo mismo que después hace el pipeline `infra`):

```bash
cd infra
tofu init -backend-config="bucket=$PROJECT_ID-tfstate"
tofu plan -var project_id=$PROJECT_ID -var ssh_public_key="$(cat ~/.ssh/clase4.pub)" -out=tfplan
tofu apply tfplan
```

La VM arranca con Docker y nada más (`infra/startup.sh`) y con el usuario `deploy`
que acepta tu clave. Entrar y traer la imagen:

```bash
ssh -i ~/.ssh/clase4 deploy@<IP>           # tofu output ssh_command
sudo docker pull us-central1-docker.pkg.dev/project-4c4f803f-f2a7-4566-9fe/infra-cloud-template/demo-c4:v1
sudo docker run -d --name app --restart unless-stopped -p 8080:8080 -v app-data:/data us-central1-docker.pkg.dev/project-4c4f803f-f2a7-4566-9fe/infra-cloud-template/demo-c4:v1
exit
```

Navegador: la URL de `tofu output app_url`.

## 5. Lo mismo, con dos pipelines

### 5.1 Una sola vez: OIDC y las dos service accounts (a mano, como dueño del proyecto)

```bash
export REPO=dpetrocelli/infra-cloud-demo-c4 POOL_ID=github-pool
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')
export COMPUTE_SA=$PROJECT_NUMBER-compute@developer.gserviceaccount.com
export INFRA_SA=infra-deployer@$PROJECT_ID.iam.gserviceaccount.com
export APP_SA=app-deployer@$PROJECT_ID.iam.gserviceaccount.com
export MEMBER="principalSet://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$POOL_ID/attribute.repository/$REPO"

gcloud services enable iam.googleapis.com iamcredentials.googleapis.com sts.googleapis.com artifactregistry.googleapis.com compute.googleapis.com

# OIDC: confiar en GitHub, solo en ESTE repo
gcloud iam workload-identity-pools create $POOL_ID --location=global --display-name="GitHub Actions"
gcloud iam workload-identity-pools providers create-oidc github-provider --location=global --workload-identity-pool=$POOL_ID --issuer-uri="https://token.actions.githubusercontent.com" --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" --attribute-condition="assertion.repository=='$REPO'"

# infra-deployer: VMs y firewall, el estado en el bucket; NO imágenes
gcloud iam service-accounts create infra-deployer --display-name="Pipeline infra"
gcloud projects add-iam-policy-binding $PROJECT_ID --member=serviceAccount:$INFRA_SA --role=roles/compute.instanceAdmin.v1
gcloud projects add-iam-policy-binding $PROJECT_ID --member=serviceAccount:$INFRA_SA --role=roles/compute.securityAdmin
gcloud iam service-accounts add-iam-policy-binding $COMPUTE_SA --member=serviceAccount:$INFRA_SA --role=roles/iam.serviceAccountUser
gcloud storage buckets add-iam-policy-binding gs://$PROJECT_ID-tfstate --member=serviceAccount:$INFRA_SA --role=roles/storage.objectAdmin
gcloud iam service-accounts add-iam-policy-binding $INFRA_SA --role=roles/iam.workloadIdentityUser --member="$MEMBER"

# app-deployer: subir imágenes y leer la IP de la VM; NO crear VMs.
# A la VM entra por SSH con la clave del secret SSH_PRIVATE_KEY, no con GCP.
gcloud iam service-accounts create app-deployer --display-name="Pipeline app"
gcloud artifacts repositories add-iam-policy-binding infra-cloud-template --location=$REGION --member=serviceAccount:$APP_SA --role=roles/artifactregistry.writer
gcloud projects add-iam-policy-binding $PROJECT_ID --member=serviceAccount:$APP_SA --role=roles/compute.viewer
gcloud iam service-accounts add-iam-policy-binding $APP_SA --role=roles/iam.workloadIdentityUser --member="$MEMBER"

# El nombre completo del provider (con el NÚMERO de proyecto)
export WIP=$(gcloud iam workload-identity-pools providers describe github-provider --location=global --workload-identity-pool=$POOL_ID --format='value(name)')
```

`roles/iam.serviceAccountUser` sobre la cuenta de Compute: infra la necesita para
crear una VM que corre como esa cuenta.

### 5.2 Variables del repo (identificadores, no secretos) y el único secret

```bash
gh variable set GCP_PROJECT_ID -R $REPO --body "$PROJECT_ID"
gh variable set GCP_WORKLOAD_IDENTITY_PROVIDER -R $REPO --body "$WIP"
gh variable set GCP_INFRA_SERVICE_ACCOUNT -R $REPO --body "$INFRA_SA"
gh variable set GCP_APP_SERVICE_ACCOUNT -R $REPO --body "$APP_SA"
gh variable set SSH_PUBLIC_KEY -R $REPO --body "$(cat ~/.ssh/clase4.pub)"
gh secret set SSH_PRIVATE_KEY -R $REPO < ~/.ssh/clase4
```

Para GCP no hay ninguna clave guardada (OIDC). El único secret es la clave SSH de la
VM: el pipeline de la app la necesita para entrar con `ssh` como lo hacés vos.

### 5.3 Usarlos

- Cambio en `infra/` → push a main → corre **infra** (plan + apply). En un PR, solo plan.
- Cambio en `app/` → push a main → corre **app**: tests, build con `APP_VERSION=<sha>`,
  push de `demo-c4:<sha>`, `docker pull` + `docker run` en la VM, y verifica que `/`
  responda con la versión nueva.

## Limpieza

```bash
cd infra && tofu destroy -var project_id=$PROJECT_ID -var ssh_public_key="$(cat ~/.ssh/clase4.pub)"
```

El pool, el provider y las service accounts no cuestan nada. Las imágenes, centavos.
