---
layout: page
show_title: false
---

{% comment %}
Adapted from https://www.patrick-wied.at/static/heatmapjs/example-heatmap-leaflet.html
{% endcomment %}

{%- capture points -%}
  [
    {% for place in site.data.places %}
      {lat: {{ place.lat }}, lng: {{ place.lon }}, count: {{ place.count }}}
      {% if forloop.index != forloop.length %},{% endif %}
    {% endfor %}
  ]
{%- endcapture -%}

{%- capture centre -%}
{{ page.lat }}, {{ page.lon }}
{%- endcapture -%}

{% include map.html maptype="fullmapdiv" mapdata=points mapcentre="53.9333, -116.5765" mapzoom=5 mapmax=1 mapradius=0.3 %}
