# opa test policy/ config/plataforma.json -v
package platform.repo_test

import rego.v1

import data.platform.repo

valida := {
	"nombre": "pagos-ledger",
	"team": "pagos",
	"tecnologia": "go",
	"nube": "azure",
	"region": "eastus",
	"teams_existentes": ["pagos", "web", "platform"],
}

test_peticion_valida if {
	count(repo.deny) == 0 with input as valida
}

test_nombre_invalido if {
	count(repo.deny) == 1 with input as object.union(valida, {"nombre": "Pagos_Ledger"})
}

test_team_inexistente if {
	count(repo.deny) == 1 with input as object.union(valida, {"team": "datos"})
}

test_team_reservado if {
	count(repo.deny) == 1 with input as object.union(valida, {"team": "platform"})
}

test_region_de_otra_nube if {
	count(repo.deny) == 1 with input as object.union(valida, {"region": "us-east-1"})
}

test_aws_valida if {
	count(repo.deny) == 0 with input as object.union(valida, {"nube": "aws", "region": "us-east-1"})
}
