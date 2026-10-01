{% from 'postgres/passwords.jinja' import passwords with context %}

salt-postgres-client:
  pkg.installed:
    - name: postgresql-client
    # The postgres_user state becomes available after psql is installed on a fresh host.
    - reload_modules: true

# The enclosing salt_config directory is 0700. Only the operator and host root can reach this
# socket; the container's mapped postgres UID needs write access to this child directory.
salt-postgres-socket-directory:
  file.directory:
    - name: /home/ubuntu/salt_config/postgres-socket
    - user: ubuntu
    - group: ubuntu
    - mode: '0733'
    - require:
      - file: salt-data-directory
    - require_in:
      - user_service: salt-postgres-running

{% for role in ('postgres', 'synapse', 'mas') %}
salt-postgres-role-{{ role }}:
  postgres_user.present:
    - name: {{ role }}
    - password: {{ passwords[role] | tojson }}
    - encrypted: scram-sha-256
    - login: true
    - user: root
    - db_user: postgres
    - db_host: /home/ubuntu/salt_config/postgres-socket
    - maintenance_db: postgres
    - require:
      - pkg: salt-postgres-client
      - user_service: salt-postgres-running
{% endfor %}
