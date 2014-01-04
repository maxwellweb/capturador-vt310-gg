class Evento
	def initialize(evento)
		@evento = evento
	end
	def encode
		resp = case @evento
				when "9955" then  61472
				when "999905" then  62465
				when "999935" then  62467
				when "999901" then  63553
				when "999931" then 63559 
				
				else
					 0
			end
		return  resp	
	end	
	def to_hex(resp)
    	"0x" + resp.to_i.to_s(16)
  	end
end