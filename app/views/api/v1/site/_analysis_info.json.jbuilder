json.set! :namespace, analysis.namespace
json.set! :name, analysis.name
json.set! :snapshot, analysis.snapshot
json.set! :description, strip_tags(analysis.description)
json.set! :entity_type, analysis.entity_type