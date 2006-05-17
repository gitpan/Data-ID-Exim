use Test::More tests => 2;

BEGIN { use_ok "Data::ID::Exim", qw(exim_mid_time); }

is exim_mid_time(1097900471), "1CIg47";
