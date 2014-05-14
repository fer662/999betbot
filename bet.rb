require 'httparty'

$kUsername = ""
$kPassword = ""
$kApiKey = ""

$kDuplications = 23	#the amount of consecutive loses you can tolerate.
					#Higher lowers income but minizes chances of going broke
$kMinBalance = 0.05	#If balance goes any lower than this the bot will stop

$kSatoshi = 0.00000001
session = ""

def martinGale(session, minBet, maxBet, startBet)

	minBet = (minBet / $kSatoshi).round
	maxBet = (maxBet / $kSatoshi).round
	startBet = (startBet / $kSatoshi).round

	return HTTParty.post("https://www.999dice.com/api/web.aspx",
    	:body => {
    		"a" => "PlaceAutomatedBets",
    		"s" => session,
    		"BasePayIn" => minBet,
    		"MaxPayIn" => maxBet,
    		"StartingPayIn" => startBet,
    		"Low" => "500500",
    		"High" => "999999",
    		"MaxBets" => "200",					#server applies our logic in between bets
    		"ResetOnWin" => "1",
    		"ResetOnLose" => "0",
    		"IncreaseOnLosePercent" => "1.0",	#duplicate when you lose
    		"StopOnLoseMaxBet" => "1",			#go back to base when you win
    		})
end

response = HTTParty.post("https://www.999dice.com/api/web.aspx",
	:body => {
		"Username" => $kUsername,
		"Password" => $kPassword,
		"a" => "Login",
		"Key" => $kApiKey
		})

if (response.success?)
	response = JSON.parse(response)
	session = response["SessionCookie"]
	lastBalance = response["Balance"].to_i * $kSatoshi
	firstBalance = lastBalance

	#recalculate min and max values to allow our setup for duplications
	minValue =  lastBalance / (2 ** ($kDuplications + 1));
	maxValue = minValue * (2 ** $kDuplications)
	startValue = minValue

	startDate = Time.now
	puts "Logged in!"
	puts "#{lastBalance}"
	
	while (lastBalance > $kMinBalance) do
		timeout = false
		begin
			#allow 12 loses in a batch, if it happens we'll wait a bit and continue manually.
			response = martinGale(session, minValue, startValue * (2**12), startValue)
		rescue Net::ReadTimeout
			puts "Timeout!"
			timeout = true
		end
		puts "#{timeout}"
		if (!timeout && response.success? && response["StartingBalance"])

			response = JSON.parse(response)
			newBalance = response["StartingBalance"].to_i * $kSatoshi
			intervalSeconds = Time.now - startDate
			bitcoinsPerSecond = (newBalance - firstBalance) / intervalSeconds
			bitcoinsPerHour = bitcoinsPerSecond * 3600
			balanceDelta = newBalance - lastBalance
			puts "Last bet %.10f Balance: %.10f (Delta: %.10f) (B/S:%.10f -> B/HR:%.10f)" % [startValue, newBalance, balanceDelta, bitcoinsPerSecond, bitcoinsPerHour]
			lastBalance = newBalance
			lost = response["PayOuts"][-1].to_i == 0
			if (lost)
				#puts "Last bet is a lose, duplicate"
				lastBet = -(response["PayIns"][-1].to_i) * $kSatoshi
				startValue = lastBet * 2
				#puts "PayInsLength#{response["PayIns"].length}"
				if (response["PayIns"].length < 200)
					puts "Waiting due to bad streak..."
					sleep(5)
				end
			else
				#puts "Last bet is a win"
				minValue = lastBalance / (2 ** (duplications + 1));
				startValue = minValue
				maxValue = minValue * (2 ** duplications)
			end

			if (newBalance < $kMinBalance)
				abort("Ouch")
			end
		end
	end

end