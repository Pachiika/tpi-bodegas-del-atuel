"""Capa de acceso a datos: una función por consulta, todo SQL parametrizado.

Regla del proyecto: ningún valor que venga del usuario se concatena dentro
del texto SQL. Siempre viaja como parámetro (%s / %(nombre)s) y el driver lo
envía separado de la sentencia, por lo que no puede cambiar su estructura.
"""
