-car = carro
-computer = computadora
  .gender = f

nicecar = Es un buen {-car}.

# Note that neither should be listed as default,
# but the format demands it.
nicecomputer = { -computer.gender ->
  *[m] Es un buen {-computer}.
   [f] Es una buena {-computer}.
}
