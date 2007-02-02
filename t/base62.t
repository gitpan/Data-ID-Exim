use Test::More tests => 7;

BEGIN { use_ok "Data::ID::Exim", qw(base62 read_base62); }

is base62(8, 1097900471), "001CIg47";
is base62(6, 1097900471), "1CIg47";
is base62(4, 1097900471), "Ig47";
is base62(0, 1097900471), "";
is read_base62("001CIg47"), 1097900471;
is read_base62(""), 0;
