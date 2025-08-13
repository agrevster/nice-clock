local j = json.load(
	'{"a_string":"hello","an_integer":1,"a_float":3.14,"a_boolean_true":true,"a_boolean_false":false,"a_null":null,"an_object":{"nested":"yes"},"an_array":[1,"two",false,null,{"deep":"object"}]}'
)
print(json.dump(j))
