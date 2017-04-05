# Validations

Crecto has several validations that are defined in the schema

## Required validation

Validates fields that are required before saving to the database

```crystal
validate_required :name  # single field
validate_require [:name, :age]  # multiple fields
```

## Format validation

Validates that a field matches a regex pattern

```crystal
validate_format :name, /^[a-zA-Z]*$/    # single field
validate_format [:first_name, :last_name], /^[a-zA-Z]*$/    # multiple fields
```

## Inclusion validation

Validates that a field is included in an array or range

```crystal
validate_inclusion :age, (21..150)			# single field
validate_incluson [:one_field, :other_field], ["a", "b", "c"]		# multiple fields
```

## Exclusion validation

Validates that a field is excluded fram an array or range

```crystal
validate_exclusion :age, (0..20) 			# single field
validate_exclusion [:one_field, :other_field], ["x", "y", "z"]		# multiple fields
```

## Validate length

Validates lengths with `:min`, `:max`, `:is`

```crystal
validate_length :password, min: 8, max: 26
validate_length :zip, is: 5
```

## Multiple validation

Assign multiple validations for one or many field(s)

```crystal
validates [:first_name, :last_name],
	precense: true,
	format: {pattern: /^[a-zA-Z]+$/},
	exclusion: {in: ["foo", "bar"]},
	length: {min: 3, max: 30}

validates :rank, inclusion: {in: 1..100}
```