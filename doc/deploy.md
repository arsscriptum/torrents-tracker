## Deploy my Stack



```
docker login

docker tag my-django-app:latest <your-dockerhub-username>/my-django-app:latest

docker push <your-dockerhub-username>/my-django-app:latest

```

To add your custom Docker image to the Portainer stack definition, you can simply reference the image you’ve built in the `docker-compose.yml` file, rather than rebuilding it in the stack. Here's a step-by-step guide on how to incorporate your custom Docker image into the stack definition for Portainer.

### Steps to Add a Custom Docker Image to Portainer Stack:

#### 1. Build and Push Your Docker Image

If you've built your Docker image locally, you need to push it to a Docker registry (such as Docker Hub or a private registry) so that Portainer can pull it.

##### Push to Docker Hub (Example):
1. **Login to Docker Hub**:
   ```bash
   docker login
   ```

2. **Tag the Image**:
   Assuming your image is built locally and tagged as `my-django-app`, you need to tag it for Docker Hub. Replace `<your-dockerhub-username>` with your actual Docker Hub username:

   ```bash
   docker tag my-django-app:latest <your-dockerhub-username>/my-django-app:latest
   ```

3. **Push the Image**:
   Now, push the image to Docker Hub:
   
   ```bash
   docker push <your-dockerhub-username>/my-django-app:latest
   ```

#### 2. Modify `docker-compose.yml` to Use Your Custom Image

Once the image is pushed to a registry, you can modify your `docker-compose.yml` to use this custom image. Here's how you do it:

##### Example `docker-compose.yml`:
Replace the `build: .` part with the image reference that you pushed to the Docker registry.

```yaml
version: '3.7'

services:
  web:
    image: <your-dockerhub-username>/my-django-app:latest  # Replace with your actual image
    command: python manage.py runserver 0.0.0.0:7070
    volumes:
      - .:/app
    ports:
      - "7070:7070"
    environment:
      - DEBUG=1
      - SERVER_HOST=0.0.0.0
      - SERVER_PORT=7070
    secrets:
      - vpn_username
      - vpn_password

  transmission-openvpn:
    container_name: transmission
    cap_add:
      - NET_ADMIN
    volumes:
      - '/srv/vpn/data:/data'
      - '/srv/vpn/config:/config'
    environment:
      - OPENVPN_PROVIDER=EXPRESSVPN
      - OPENVPN_CONFIG=/data/config/ny.ovpn
      - OPENVPN_USERNAME=/run/secrets/vpn_username
      - OPENVPN_PASSWORD=/run/secrets/vpn_password
      - VPN_ENABLED=yes
      - CREATE_TUN_DEVICE=true
      - LAN_NETWORK=10.0.0.0/24
      - NAME_SERVERS=1.1.1.1,1.0.0.1
      - LOCAL_NETWORK=10.0.0.0/24
      - TZ=America/New_York
    logging:
      driver: "json-file"
      options:
        max-size: 10m
    ports:
      - 7071:7071
    image: haugene/transmission-openvpn

secrets:
  vpn_username:
    file: /srv/secrets/vpn_username.txt
  vpn_password:
    file: /srv/secrets/vpn_password.txt
```

### 3. Deploy the Updated Stack in Portainer

Now that your `docker-compose.yml` is updated with your custom image, follow these steps to deploy it in Portainer:

1. **Navigate to Stacks**: In the Portainer UI, go to **Stacks**.
   
2. **Add or Edit the Stack**: If you’re creating a new stack, click on **"Add stack"**, or if you're updating an existing one, click the stack name and then **"Update stack"**.

3. **Upload or Paste the `docker-compose.yml` File**: 
   - You can either **upload** the updated `docker-compose.yml` file or **copy and paste** the file content into the Portainer editor.
   
4. **Deploy or Update the Stack**: Once you've made the changes, click on **"Deploy the stack"** or **"Update the stack"** (if editing).

### 4. Verifying the Deployment

- **Check the Containers**: Go to **Containers** under the stack in Portainer and verify that the `web` service is pulling your custom image from Docker Hub.
- **Logs**: Check the logs in Portainer to ensure the application is running as expected.
- **Access**: Once the stack is running, access your Django application via `http://<YOUR_DOCKER_HOST>:7070`.

With these steps, you can successfully add your custom Docker image to your Portainer stack definition and deploy it. Let me know if you need further assistance!
