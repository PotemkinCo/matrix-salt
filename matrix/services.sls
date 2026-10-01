include:
  - matrix.units
  - matrix.runtime
  - matrix.release
  - postgres.roles

# The pod is created after all Quadlet definitions are present. StartWithPod=false on each
# container prevents the pod from bypassing the database and application ordering below.
salt-pod-running:
  user_service.running:
    - name: salt-pod.service
    - user: ubuntu
    - timeout: 900
    - require:
      - service: salt-user-manager
      - user_service: salt-pod-quiescent
      - file: salt-pod-quadlet
      - file: salt-quadlet-postgres
      - file: salt-quadlet-mas
      - file: salt-quadlet-synapse
      - file: salt-quadlet-lk-jwt

salt-postgres-running:
  user_service.running:
    - name: salt-postgres.service
    - user: ubuntu
    - timeout: 900
    - require:
      - user_service: salt-pod-running
      - user_service: salt-postgres-quiescent
      - file: salt-quadlet-postgres
      - file: salt-release-postgres
      - file: salt-postgres-socket-directory
      - file: salt-secret-postgres-secrets-env
      - file: salt-secret-synapse-db-secrets-env
      - file: salt-secret-mas-db-secrets-env
      - file: salt-deployment-environment

salt-mas-running:
  user_service.running:
    - name: salt-mas.service
    - user: ubuntu
    - timeout: 900
    - require:
      - user_service: salt-postgres-running
      - user_service: salt-mas-quiescent
      - postgres_user: salt-postgres-role-postgres
      - postgres_user: salt-postgres-role-mas
      - file: salt-quadlet-mas
      - file: salt-release-mas
      - file: salt-mas-runtime
      - file: salt-mas-environment
      - file: salt-deployment-environment
      - file: salt-secret-mas-secrets-json
      - file: salt-secret-mas-signing-key

salt-synapse-running:
  user_service.running:
    - name: salt-synapse.service
    - user: ubuntu
    - timeout: 900
    - require:
      - user_service: salt-mas-running
      - user_service: salt-synapse-quiescent
      - postgres_user: salt-postgres-role-synapse
      - file: salt-quadlet-synapse
      - file: salt-release-synapse
      - file: salt-synapse-runtime
      - file: salt-synapse-log-config
      - file: salt-deployment-environment
      - file: salt-secret-synapse-secrets-json
      - file: salt-secret-synapse-signing-key
      - file: salt-secret-lk-jwt-appservice-yaml

salt-lk-jwt-running:
  user_service.running:
    - name: salt-lk-jwt.service
    - user: ubuntu
    - timeout: 900
    - require:
      - user_service: salt-synapse-running
      - user_service: salt-lk-jwt-quiescent
      - file: salt-quadlet-lk-jwt
      - file: salt-deployment-environment
      - file: salt-secret-lk-jwt-secrets-env
      - file: salt-secret-lk-jwt-appservice-yaml
