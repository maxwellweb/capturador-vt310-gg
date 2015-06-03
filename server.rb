#!/usr/bin/env ruby
require 'socket'
require 'gps_parser'
require 'mysql2'
require 'logger'
require 'geokit'
require "#{Dir.pwd}/lib/evento.rb"
include Geokit::Geocoders

if ARGV.empty?
	puts "Uso: # ruby server.rb start/stop"
	exit
end
if ARGV[0] == "start"
  s = UDPSocket.new
  pid = Process.pid
  s.bind('0.0.0.0', 4042)
  client = Mysql2::Client.new(:host => 'localhost', :username => 'USUARIO', :password => 'PASSWORD', :database => 'BASEDEDATOS')
  puts "==Iniciando Server=="
  puts "==PID: #{pid}=="
  open( '/tmp/server.pid', 'w') do |f|
    f.print( pid )
  end
  loop {
    hoy = Time.now.strftime('%d-%m-%Y-%H-%M')
    data, sender = s.recvfrom(1024)
    remote_host = sender[3]
    log = Logger.new("#{Dir.pwd()}/logs/log.txt", "daily")
    log.debug "[#{hoy}] -- [#{sender[3]}] -- Recibido : #{data}"
    /\$+(?<v1>\d+)\?+&A(?<v2>\w+)/ =~ data
    parseo = data.split(",")
    idUnico = v1
    eventGPS = Evento.new("#{v2}")
    eventHex = eventGPS.to_hex("#{eventGPS.encode}")
    latitud = GPS::parse_latitude parseo[2].to_f, parseo[3]
    longitud = GPS::parse_longitude parseo[4].to_f, parseo[5]
    speedKPH = parseo[6]
    course = parseo[7]
    rev = GoogleGeocoder.reverse_geocode([latitud, longitud])

    puts "Host entrante: #{remote_host}"
    puts "Datos recividos: #{data}"
    puts "ID GPS: #{idUnico}"  
    puts "Evento del GPS: #{eventGPS.encode}"
    puts "Evento Hex : #{eventHex}"
    puts "La Latitud es: #{latitud}"
    puts "La longitud es: #{longitud}"
    puts "La direccion es: #{rev.full_address}"
    puts "#{speedKPH}"
    puts "#{course}"
    res = client.query("SELECT * FROM Device WHERE uniqueID = #{idUnico}")

    if res.count > 0
      puts "GPS Existe"
      upd = client.query("UPDATE Device SET ignitionIndex = 99, lastValidLatitude = #{latitud}, lastValidLongitude = #{longitud}, lastGPSTimestamp = #{Time.now.to_i}, lastUpdateTime = #{Time.now.to_i} WHERE uniqueID = #{idUnico}")
      if upd == nil
        puts "Se actualizo las ultimas coordenadas en la db correctamente de: #{idUnico}"
        ins = "INSERT INTO EventData( accountID, deviceID, timestamp, statusCode, latitude, longitude, speedKPH, heading, address, creationTime ) VALUES ( (SELECT accountID FROM Device WHERE uniqueID = #{idUnico}), (SELECT deviceID FROM Device WHERE uniqueID = #{idUnico}), #{Time.now.to_i}, #{eventGPS.encode}, #{latitud}, #{longitud}, #{speedKPH}, #{course}, '#{rev.full_address.to_s}', #{Time.now.to_i})"
        insert = client.query(ins)
        if insert == nil
          puts "Se inserto correctamente la posicion de: #{idUnico}"
        else
          puts "no se pudo insertar posicion en la base de datos"
        end
      else
        puts "no se grabo en la db"
      end
    else
      puts "GPS No Existe! en la base de datos"
    end

  }
elsif ARGV[0] == "stop"
	lpid = File.read("/tmp/server.pid")
	Process.kill(9, lpid.to_i)
	puts "mantando proceso #{lpid} #{Time.now.ctime}"
else
	puts "Uso: # ruby server.rb start/stop"
end
