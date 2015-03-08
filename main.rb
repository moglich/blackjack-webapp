require 'rubygems'
require 'sinatra'
require 'pry'

use Rack::Session::Cookie, :key => 'rack.session',
                           :path => '/',
                           :secret => 'AS21-12mix1%mmX$fj3A-fm238l32' 

START_MONEY = 500
LMT_DEALER_HIT = 17
LMT_BLACKJACK = 21

helpers do

  def new_deck
    deck = {  clubs: [],
              diamonds: [],
              hearts: [],
              spades: [] }

    deck.each_key do |card_type|
      (2..10).each do |value|
        deck[card_type] << { value.to_s => value }
      end
      deck[card_type] << { "jack"  => 10 }
      deck[card_type] << { "queen" => 10 }
      deck[card_type] << { "king"  => 10 }
      deck[card_type] << { "ace"   => 11 }
    end

    deck
  end

  def get_card(cards) #{:hearts => [{"2" => 2}, {"3" => 3}, {"4" => 4}], :spades => [{"2" => 2}, {"3" => 3}]}

    deck = cards.index(cards.sample)
    card_type = cards[deck].keys.sample
    card_value = cards[deck][card_type].sample

    cards[deck][card_type].delete(card_value)

    if cards[deck][card_type].empty?
      cards[deck].delete card_type
    end

    card = { card_type => card_value }
  end
  # >> {"2" => 2}

  def show_cards(cards, show_first=true)
    card_stack = ""

    if show_first
      session[cards].each do |card|
        card.each do |suit, card|
          card_stack << "<div class=\"cards\">
            <img src=\"/images/cards/#{suit.to_s}_#{card.first[0]}.jpg\" class=\"img-rounded card-border img-xs\">
          </div>"
        end
      end
    else
      session[cards].first.each do |suit, card|
        card_stack << "<div class=\"cards\">
                        <img src=\"/images/cards/#{suit.to_s}_#{card.first[0]}.jpg\" class=\"img-rounded card-border img-xs\">
                       </div>"
      end
      card_stack << "<div class=\"cards\">
                       <img src=\"/images/cards/cover.jpg\" class=\"img-rounded card-border img-xs\">
                     </div>"
    end
    card_stack
  end

  def get_total(cards) #[{:hearts=>{"queen"=>10}}, {:spades=>{"7"=>7}}]
    value = 0
    ace_cnt = 0

    cards.each do |card_type|
      card_type.each_value do |card|
        card.each_value do |val|
          if val == 11
            ace_cnt += 1
          end
          value += val
        end
      end
    end

    while (value > LMT_BLACKJACK) && (ace_cnt > 0)
      value -= 10
      ace_cnt -= 1
    end

    value
  end

  def busted?(cards)
    get_total(cards) > LMT_BLACKJACK ? true : false
  end

  def blackjack?(cards)
    get_total(cards) == LMT_BLACKJACK ? true : false
  end

  def show_winner!(cards_dealer, cards_player)

    value_player = get_total(cards_player)
    value_dealer = get_total(cards_dealer)

    if (value_player > LMT_BLACKJACK) && (value_dealer > LMT_BLACKJACK)
      game_state!(:busted_both)
    elsif value_player > LMT_BLACKJACK
      game_state!(:busted_player)
    elsif value_dealer > LMT_BLACKJACK
      game_state!(:busted_dealer)
    elsif value_dealer == value_player
      game_state!(:push)
    elsif value_player == LMT_BLACKJACK
      game_state!(:winner_player)
    elsif value_dealer < value_player
      game_state!(:winner_player)
    elsif value_dealer > value_player
      game_state!(:winner_dealer)
    end
  end

  def status_msg!(state, msg="")
    case state
    when :push
      level = "warning"

    when :winner_player
      level = "success"

    when :winner_dealer
      level = "danger"
    else
      level = "info"
    end

    if state != :reset
      session[:status_msg] = "<div class=\"alert alert-#{level}\">#{msg}</div>"
    else
      session[:status_msg] = nil
    end
  end

  def game_state!(state)
    case state
    when :player_turn
      session[:game_state] = :player_turn
    when :busted_player
      session[:game_state] = :busted_player
      loose_money!
      status_msg!(:winner_dealer, "You are busted, #{session[:username]}!")
    when :blackjack_player
      win_money!
      status_msg!(:winner_player, "You got a blackjack, #{session[:username]}!")
      game_state!(:stop)
    when :winner_player
      win_money!
      status_msg!(:winner_player, "You won, #{session[:username]}!")
      game_state!(:stop)

    when :dealer_turn
      session[:game_state] = :dealer_turn
    when :busted_dealer
      win_money!
      session[:game_state] = :busted_dealer
      status_msg!(:winner_player, "Dealer is busted, you won!")
    when :winner_dealer
      loose_money!
      status_msg!(:winner_dealer, "Dealer won, you lost #{session[:username]}!")
      game_state!(:stop)

    when :push
      status_msg!(:push, "It's a push!")
      game_state!(:stop)
    when :stop
      session[:game_state] = :stop
    end
  end

  def loose_money!
    session[:money] = session[:money] - session[:bet]
  end

  def win_money!
    session[:money] = session[:money] + session[:bet]
  end
end

get '/' do
  if session[:username]
    redirect '/new_game'
  else
    redirect '/new_player'
  end
end

get '/logout' do
  session[:username] = nil
  redirect '/'
end

get '/new_player' do
  erb :new_player
end

post '/new_player' do
  session[:username] = params[:username]
  session[:money] = START_MONEY
  redirect '/bet'
end

get '/bet' do
  if !session[:username]
    redirect '/new_player'
  end

  status_msg!(:reset)

  erb :bet
end

post '/bet' do
  session[:bet] = params[:bet].to_i

  if session[:bet] <= 0
    status_msg!(:bet_to_high, "Please enter an amount higher than 0!")
    halt erb :bet
  end

  if session[:bet] > session[:money]
    status_msg!(:bet_to_high, "Your bet is higher than your actual money!")
    halt erb :bet
  end

  redirect '/new_game'
end

get '/new_game' do
  if !session[:username]
    redirect '/new_player'
  end

  status_msg!(:reset)
  game_state!(:player_turn)

  session[:deck] = new_deck

  session[:dealer_cards] = []
  session[:player_cards] = []

  2.times do
    session[:dealer_cards] << get_card([session[:deck]])
    session[:player_cards] << get_card([session[:deck]])
  end

  if blackjack?(session[:player_cards])
    if blackjack?(session[:dealer_cards])
      game_state!(:push)
    else
      game_state!(:blackjack_player)
    end
  end

  redirect '/game'
end

get '/game' do
  if !session[:username]
    redirect '/new_player'
  end

  if !session[:bet]
    redirect '/bet'
  end

  erb :game
end

post '/game/player/hit' do
  session[:player_cards] << get_card([session[:deck]])

  if busted?(session[:player_cards])
    game_state!(:busted_player)
  end

  #redirect '/game'
  erb :game, layout: false
end

post '/game/player/stay' do
  game_state!(:dealer_turn)

  while get_total(session[:dealer_cards]) < LMT_DEALER_HIT
    session[:dealer_cards] << get_card([session[:deck]])
  end

  if busted?(session[:dealer_cards])
    game_state!(:busted_dealer)
  end

  show_winner!(session[:dealer_cards], session[:player_cards])

  erb :game, layout: false
end
