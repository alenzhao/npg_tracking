use strict;
use warnings;
use Test::More tests => 24;
use Test::Exception;
use t::util;

use_ok('npg::model::instrument_status');

my $util = t::util->new({fixtures => 1});

my $already_at_status_wash_required = npg::model::instrument_status->new({
                    util => $util,
                    id_instrument_status => 5,
                   });
my $already_at_status_down = npg::model::instrument_status->new({
                 util => $util,
                 id_instrument_status => 4,
                });
my $already_at_status_up = npg::model::instrument_status->new({
                     util => $util,
                     id_instrument_status => 13,
                    });

{
  my $model = npg::model::instrument_status->new({ util => $util });
  ######
  # test current_instrument_statuses and latest_current_instrument_status
  #
  my $current_instrument_statuses = $model->current_instrument_statuses();
  isa_ok($current_instrument_statuses, 'ARRAY', '$model->current_instrument_statuses()');
  is($model->current_instrument_statuses(), $current_instrument_statuses, '$model->current_instrument_statuses() cached ok');
  $model->{'current_instrument_statuses'} = undef;
  my $limit_current_instrument_statuses = $model->current_instrument_statuses(1);
  isnt($limit_current_instrument_statuses, $current_instrument_statuses, 'retrieves with a limit included - different result to without limit');
  my $latest_current_instrument_status = $model->latest_current_instrument_status();
  isa_ok($latest_current_instrument_status, 'npg::model::instrument_status', '$model->latest_current_instrument_status()');
  is($model->latest_current_instrument_status(), $latest_current_instrument_status, '$model->latest_current_instrument_status() cached ok');

  #######
  # test getting the objects related to join table
  is($already_at_status_up->instrument->name(), 'IL10', '$model->instrument() returns correct object - checked via name');
  is($already_at_status_up->user->username(), 'joe_admin', '$model->user() returns correct object - checked via username');
  is($already_at_status_up->instrument_status_dict->description(), 'up', '$model->instrument_status_dict() returns correct object - checked via description');

 
  $model = npg::model::instrument_status->new({
    util => $util,
    id_instrument => $already_at_status_up->instrument->id_instrument(),
    id_user => $already_at_status_up->user->id_user(),
    id_instrument_status_dict => 4,
  });
  throws_ok { $model->_check_order_ok(); }
    qr/Instrument IL10 \"wash performed\" status cannot follow current \"up\"/,
    q{error moving from 'up' to 'wash performed'};

  $model = npg::model::instrument_status->new({
    util => $util,
    id_instrument => $already_at_status_up->instrument->id_instrument(),
    id_user => $already_at_status_up->user->id_user(),
    id_instrument_status_dict => 2,
  });
  throws_ok  { $model->_check_order_ok(); }
    qr/Status \"down\" is deprecated/,
    q{croak on trying to move to deprecated status};

  $model = npg::model::instrument_status->new({
    util => $util,
    id_instrument => $already_at_status_up->instrument->id_instrument(),
    id_user => $already_at_status_up->user->id_user(),
    id_instrument_status_dict => 8,
  });
  lives_ok  { $model->_check_order_ok(); }
    q{can move from 'up' to 'down for repair'};

  $model = npg::model::instrument_status->new({
    util => $util,
    id_instrument => $already_at_status_up->instrument->id_instrument(),
    id_user => $already_at_status_up->user->id_user(),
    id_instrument_status_dict => 3,
  });
  lives_ok { $model->_check_order_ok(); }  q{no croak on moving status to 'wash required' from 'up'};

  $model = npg::model::instrument_status->new({
    util => $util,
    id_instrument => $already_at_status_up->instrument->id_instrument(),
    id_user => $already_at_status_up->user->id_user(),
    id_instrument_status_dict => 7,
  });
  lives_ok { $model->_check_order_ok(); } q{no croak on moving status to 'planned repear' from 'up'};

  $model = npg::model::instrument_status->new({
    util => $util,
    id_instrument => $already_at_status_wash_required->instrument->id_instrument(),
    id_user => $already_at_status_wash_required->user->id_user(),
    id_instrument_status_dict => 11,
  });
  lives_ok { $model->_check_order_ok(); }
    q{no croak on moving status to 'wash in progress' from 'wash required'};

  $model = npg::model::instrument_status->new({
    util => $util,
    id_instrument => $already_at_status_wash_required->instrument->id_instrument(),
    id_user => $already_at_status_wash_required->user->id_user(),
    id_instrument_status_dict => 1,
  });
  throws_ok { $model->_check_order_ok(); }
    qr/Instrument IL5 \"up\" status cannot follow current \"wash required\" status/,
    q{error on moving status to 'up' from 'wash required'};

  $model = npg::model::instrument_status->new({
                 util => $util,
                 id_instrument => $already_at_status_down->instrument->id_instrument(),
                 id_user => $already_at_status_down->user->id_user(),
                 id_instrument_status_dict => 5,
                });
}

{
  my $model = npg::model::instrument_status->new({
              util => $util,
              id_instrument => 13,
              id_instrument_status_dict => 8,
              id_user => 4,
             });
  $util->requestor('joe_engineer');
  lives_ok { $model->create(); }  q{no croak on create of 'down for repair' status for id_instrument 13};
  $model = npg::model::instrument->new({util => $util, id_instrument => 13});
  cmp_ok(npg::model::instrument->new({util => $util, id_instrument => 13})
     ->current_instrument_status->instrument_status_dict->description, 'eq',
    'down for repair', 'down for repair is current status in database');
}

{
  my $model = npg::model::instrument_status->new({
    util => $util,
    id_instrument => 8,
    id_instrument_status_dict => 11,
    id_user => 4,
  });
  lives_ok { $model->create(); } 'no croak on create of wash in progress status for id_instrument 8';

  $model = npg::model::instrument_status->new({
    util => $util,
    id_instrument => 8,
    id_instrument_status_dict => 4,
    id_user => 4,
  });
  lives_ok { $model->create(); } 'no croak on create of wash performed status for id_instrument 8';

  cmp_ok(npg::model::instrument->new({util => $util, id_instrument => 8})
    ->current_instrument_status->instrument_status_dict->description, 'eq',
    'up', 'up is current status in database (automatic from wash performed)');

  $model = npg::model::instrument_status->new({
    util => $util,
    id_instrument => 8,
    id_instrument_status_dict => 7,
    id_user => 4,
  });
  lives_ok { $model->create(); } 'no croak on create of planned repair status for id_instrument 8';
}

{
  my $model = npg::model::instrument_status->new({
    util => $util,
    id_instrument_status => 5,
  });
  is(scalar @{$model->annotations}, 2, 'two annotations returns for this instrument_status');
  is($model->annotations->[1]->comment, 'Solexa test flowcell - New paired end module', 'correct comment for the second annotation');
}

1;
