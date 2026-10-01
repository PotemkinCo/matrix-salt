{% import_json "versions.json" as versions %}
{% set vars = pillar["matrix"] %}
{% set commit = pillar["deployment"].get("commit", "") %}
{% set data_dir = "/home/ubuntu/salt_config" %}
{% set image_vars = {
  "SYNAPSE_IMAGE": "synapse",
  "MAS_IMAGE": "mas",
  "LK_JWT_IMAGE": "lk_jwt",
  "POSTGRES_IMAGE": "postgres"
} %}
{% set selected_images = versions["images"] %}
{% if commit is not string or commit|length != 40 or commit|reject("in", "0123456789abcdef")|list|length > 0 %}
  {{ salt["test.raise_exception"]("ValueError", "pillar deployment.commit must be a full lowercase Git commit id") }}
{% endif %}
{% set images = {} %}
{% for env_key, name in image_vars.items() %}
  {% set ref = selected_images.get(name, "") %}
  {% if ref is not string or not ref|regex_match("^[A-Za-z0-9][A-Za-z0-9._/:@-]*$") %}
    {{ salt["test.raise_exception"]("ValueError", "versions.json images." ~ name ~ " must be a non-empty container image reference") }}
  {% endif %}
  {% set _ = images.update({env_key: ref}) %}
{% endfor %}
{% set activation = {
  "status": "succeeded",
  "server_name": vars["server"]["name"],
  "commit": commit,
  "images": images
} %}

include:
  - matrix.release

salt-activation:
  file.serialize:
    - name: {{ data_dir }}/deploy-state/activation.json
    - serializer: json
    - dataset: {{ activation | tojson }}
    - user: ubuntu
    - group: ubuntu
    - mode: '0600'
    - show_changes: false
    - require:
      - user_service: salt-postgres-running
      - user_service: salt-mas-running
      - user_service: salt-synapse-running
      - user_service: salt-lk-jwt-running
      # The record must not be written before the full ingress configuration is applied and HAProxy
      # reconciled, otherwise a host can advertise a commit whose public entrypoint was never applied.
      - service: salt-matrix-ingress-service
