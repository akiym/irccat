requires 'perl', '5.008001';
requires 'AnyEvent';
requires 'AnyEvent::IRC';

on 'test' => sub {
    requires 'Test::More', '0.98';
};

