# digitalocean-image-registry-autocleanup

Since DigitalOcean registry doesn't have way to clean up unused image automatically. We create this script to clean up images that are older than 7 days, which can be call from CronJob in Kubernetes.

Any images older than 7 days will be delete except for images with these condition:
- Image with tag = latest
- Image that are currently use by any pod within the cluster
- Image with tag x.x.x where x is digits


## Usage
We recommend creating a CronJob inside the K8S cluster, for example:

```yaml
apiVersion: batch/v1beta1
kind: CronJob
metadata:
  namespace: registry-cleaner
  name: registry-cleaner
spec:
  schedule: "0 3 * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: registry-cleaner
            image: thegang/digitalocean-image-registry-autocleanup:latest
            imagePullPolicy: Always
            env:
            - name: DO_REGISTRY_NAME
              value: your-registry-name
            - name: DO_ACCESS_TOKEN
              valueFrom:
                secretKeyRef:
                  name: do-secret-key
                  key: DO_ACCESS_TOKEN
          restartPolicy: OnFailure
      backoffLimit: 4
```

**The service account that attach to the pod must have ClusterRole with get & list access to pods**
```
  - verbs:
      - get
      - list
    apiGroups:
      - ''
    resources:
      - pods
```

Also create a **do-secret-key** containing your personal DigitalOcean API Key
