use Test;
use Fluent;


add-localization-basepath("t/02-data/");
add-localization-languages("es", "es-ES", "es-AR", "es-CL");

# Default message, absent specific regional information
is localized("nicecar", :language<es>), "Es un buen carro.";
# The -ES takes priority, and gives "coche"
is localized("nicecar", :languages<es es-ES>), "Es un buen coche.";
# The -AR takes priority, and gives "auto"
is localized("nicecar", :languages<es es-AR>), "Es un buen auto.";
# There is no MX, so tag matching falls back to "es""
is localized("nicecar", :language<es-MX>    ), "Es un buen carro.";

# Default message, absent specific regional information
is localized("nicecomputer", :language<es>), "Es una buena computadora.";
# The -ES takes priority, with gives masculine "ordenador"
is localized("nicecomputer", :languages<es es-ES>), "Es un buen ordenador.";
# The -CL takes priority, with masculine "computador
is localized("nicecomputer", :languages<es es-CL>), "Es un buen computador.";
# es-AR exists, but -computer isn't found, so fall back to "es"
# This one is currently buggy, TODO: fix it
#is localized("nicecomputer", :language<es-AR>), "Es una buena computadora.";
done-testing();
