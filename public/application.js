$(document).ready(function(){
  player_hit();
  player_stay();

});

function player_hit(){
  $(document).on('click', 'form#hit', function(){

  $.ajax({
    type: 'POST',
    url: '/game/player/hit'
    }).done(function(msg){
      $('#game').replaceWith(msg);
    });

    return false;
  });
}

function player_stay(){
  $(document).on('click', 'form#stay', function(){

  $.ajax({
    type: 'POST',
    url: '/game/player/stay'
    }).done(function(msg){
      $('#game').replaceWith(msg);
    });

    return false;
  });
}
