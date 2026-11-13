# Reglas de una petición de servicio, como política en código.
# Apagada en el Módulo 1: platformctl valida en Go. En M2 · Clase 3 se enciende con la
# variable de organización POLICY_ENABLED=true y entonces validate() usa esta política.
#
# input: {nombre, team, tecnologia, nube, region, ambiente, tamano, teams_existentes: [...]}
# data:  config/plataforma.json (nombre_regex, plantillas, nubes, ambientes, tamanos, teams_reservados)
package platform.repo

import rego.v1

deny contains msg if {
	not regex.match(data.nombre_regex, input.nombre)
	msg := sprintf("el nombre '%s' no cumple la convención: %s", [input.nombre, data.nombre_ayuda])
}

deny contains msg if {
	not input.team in input.teams_existentes
	msg := sprintf("el team '%s' no existe en la organización", [input.team])
}

deny contains msg if {
	input.team in data.teams_reservados
	msg := sprintf("el team '%s' no puede ser dueño de un servicio", [input.team])
}

deny contains msg if {
	not data.plantillas[input.tecnologia]
	msg := sprintf("no hay plantilla para la tecnología '%s'", [input.tecnologia])
}

deny contains msg if {
	not data.nubes[input.nube]
	msg := sprintf("la nube '%s' no está soportada", [input.nube])
}

deny contains msg if {
	nube := data.nubes[input.nube]
	not input.region in nube.regiones
	msg := sprintf("la región '%s' no está permitida en %s (permitidas: %s)", [input.region, input.nube, concat(", ", nube.regiones)])
}

deny contains msg if {
	not input.ambiente in data.ambientes
	msg := sprintf("el ambiente '%s' no existe (ambientes: %s)", [input.ambiente, concat(", ", data.ambientes)])
}

deny contains msg if {
	not data.tamanos[input.tamano]
	msg := sprintf("el tamaño '%s' no existe", [input.tamano])
}

# La regla de seis líneas de M2 · Clase 3: tamaños no permitidos (la de regiones está arriba).
# La lámina de esa clase copia estas seis líneas: si cambian, actualizarla.
deny contains msg if {
	data.tamanos[input.tamano]
	not input.tamano in data.tamanos_permitidos
	permitidos := concat(", ", data.tamanos_permitidos)
	msg := sprintf("el tamaño '%s' no está permitido (permitidos: %s)", [input.tamano, permitidos])
}
