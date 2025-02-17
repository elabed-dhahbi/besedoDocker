DevOps/SRE Technical Test Solutions

Containerization with Docker

Overview

This project includes Dockerfiles for containerizing the Falcon backend (Golang) and Ariane frontend (Node.js). Each service is built separately and runs inside a Docker container.

Dockerfiles

Falcon (Backend)

File: Dockerfile.falcon
```
FROM golang:1.20-alpine  # Use Golang 1.20 Alpine image for lightweight container
WORKDIR /app             # Set working directory inside the container
COPY . .                 # Copy all project files
RUN go mod tidy && go build -o /usr/local/bin/falcon  # Download dependencies & build the binary
ENTRYPOINT ["falcon"]    # Run Falcon binary as entrypoint
EXPOSE 4000              # Expose port 4000 for API communication

```

Explanation:

Uses Go 1.20 Alpine for a minimal base image.

Installs dependencies with go mod tidy.

Compiles the application and places the binary in /usr/local/bin/falcon.

Sets ENTRYPOINT ["falcon"] to directly run the built binary.

Exposes port 4000 for API access.

Ariane (Frontend)

File: Dockerfile.ariane
```
FROM node:18-alpine  # Use lightweight Node.js image
WORKDIR /app         # Set working directory inside the container
COPY package.json package-lock.json ./  # Copy only package files first (for better caching)
RUN npm install      # Install dependencies
COPY . .             # Copy remaining application files
RUN npm run build  # Dummy build step, prevents Docker failure
CMD ["npm", "start"]  # Use the start script from package.json
EXPOSE 3000          # Expose port 3000 for frontend service

```

Explanation:

Uses Node.js 18 Alpine for a minimal footprint.

Separates dependency installation from the full copy to leverage Docker layer caching.

Runs the application with npm start.

Exposes port 3000.

Fixes in package.json

The original package.json did not contain a build script, which caused Docker to fail when running:

RUN npm install && npm run build

Since npm run build was missing, we had to modify package.json to include the build step.

Original package.json (Before Fix)
``` 

{
  "name": "ariane",
  "version": "1.0.0",
  "description": "",
  "main": "index.js",
  "scripts": {
    "test": "echo \"Error: no test specified\" && exit 1"
  },
  "dependencies": {
    "express": "^4.18.2"
  }
}
```
Updated package.json (After Fix)

I added a start script and a dummy build step to prevent Docker errors.
```
{
  "name": "ariane",
  "version": "1.0.0",
  "description": "",
  "main": "app.js",
  "scripts": {
    "start": "node app.js",
    "build": "echo 'No build step needed for Ariane'"
  },
  "dependencies": {
    "express": "^4.18.2"
  }
}
```

Why This Fix Works

✅ Added "start": "node app.js" so that Docker can run it properly.

✅ Created "build": "echo 'No build step needed'" to prevent Docker from failing when running npm run build.

✅ Ensured the main entry file is app.js, which aligns with the Docker CMD.

Redis (Database)
File: Dockerfile

```

FROM redis:latest  # Use the latest Redis image
CMD ["redis-server", "--port", "6399"]  # Start Redis on port 6399
EXPOSE 6399  # Expose Redis service
```

Explanation:

Uses official Redis image.

Configures Redis to run on port 6399 as per requirements.

Exposes port 6399.
Building and Running the Containers

Build the Images

# Build Falcon (Backend)
docker build -t falcon-image -f Dockerfile.falcon .

# Build Ariane (Frontend)
docker build -t ariane-image -f Dockerfile.ariane .

# Build Redis (Database)
docker build -t redis-image -f Dockerfile .

Run the Containers

# Run Falcon (Backend) container
docker run -d --name falcon-container -p 4000:4000 falcon-image

# Run Ariane (Frontend) container
docker run -d --name ariane-container -p 3000:3000 ariane-image

# Run Redis (Database) container
docker run -d --name redis-container -p 6399:6399 redis-image

Verify Containers are Running

docker ps

Test Access

Ariane (Frontend): Open http://localhost:3000 in a browser.



Conclusion

Falcon (Golang) now builds properly and runs as an executable.

Ariane (Node.js) was fixed to bind to 0.0.0.0, ensuring external access.

Both applications are containerized using efficient Dockerfile best practices.


**Kubernetes Configuration**

ConfigMaps

The ConfigMaps store environment variables for the services to ensure proper connectivity between components.

Falcon ConfigMap
```
apiVersion: v1
kind: ConfigMap
metadata:
  name: falcon-config
data:
  REDIS_HOST: "redis-service"
  REDIS_PORT: "6399"
```
Ariane ConfigMap
```
apiVersion: v1
kind: ConfigMap
metadata:
  name: ariane-config
data:
  API_URL: "http://falcon-service:4000"
```
Services

These services expose the deployments to internal and external connections.

Ariane Service
```
apiVersion: v1
kind: Service
metadata:
  name: ariane-service
spec:
  selector:
    app: ariane
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
```
Falcon Service
```
apiVersion: v1
kind: Service
metadata:
  name: falcon-service
spec:
  selector:
    app: falcon
  ports:
    - protocol: TCP
      port: 4000
      targetPort: 4000
```
Redis Service

```
apiVersion: v1
kind: Service
metadata:
  name: redis-service
spec:
  selector:
    app: redis
  ports:
    - protocol: TCP
      port: 6399
      targetPort: 6399
```
Deployments

The deployments manage the application replicas and configuration.
```
Ariane Deployment

apiVersion: apps/v1
kind: Deployment
metadata:
  name: ariane-deployment
spec:
  replicas: 2
  selector:
    matchLabels:
      app: ariane
  template:
    metadata:
      labels:
        app: ariane
    spec:
      containers:
        - name: ariane
          image: ariane-image:latest
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 80
          env:
            - name: API_URL
              valueFrom:
                configMapKeyRef:
                  name: ariane-config
                  key: API_URL
```
Falcon Deployment
```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: falcon-deployment
spec:
  replicas: 2
  selector:
    matchLabels:
      app: falcon
  template:
    metadata:
      labels:
        app: falcon
    spec:
      containers:
        - name: falcon
          image: falcon-image:latest
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 4000
          env:
            - name: REDIS_HOST
              valueFrom:
                configMapKeyRef:
                  name: falcon-config
                  key: REDIS_HOST
            - name: REDIS_PORT
              valueFrom:
                configMapKeyRef:
                  name: falcon-config
                  key: REDIS_PORT
```
Persistent Storage for Redis
```
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: redis-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: longhorn
```
Redis Deployment

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis-deployment
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
        - name: redis
          image: custom-redis:latest
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 6399
          volumeMounts:
            - mountPath: /data
              name: redis-storage
      volumes:
        - name: redis-storage
          persistentVolumeClaim:
            claimName: redis-pvc
```
Conclusion

ConfigMaps are used to manage configuration dynamically.

Ariane and Falcon deployments now load their environment variables from ConfigMaps.

Redis deployment uses persistent storage.

**Each component is deployed and accessible through its respective Kubernetes service.
