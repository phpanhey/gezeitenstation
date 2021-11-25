require 'socket'
require 'net/http'
require 'json'

url_vegesack = 'http://pegelonline.wsv.de/webservices/rest-api/v2/stations/VEGESACK.json?includeTimeseries=true&includeCurrentMeasurement=true'
url_brake = 'http://pegelonline.wsv.de/webservices/rest-api/v2/stations/BRAKE.json?includeTimeseries=true&includeCurrentMeasurement=true'
url_bhv_alter_leuchtturm = 'http://pegelonline.wsv.de/webservices/rest-api/v2/stations/BHV%20ALTER%20LEUCHTTURM.json?includeTimeseries=true&includeCurrentMeasurement=true'
url_hb_grosse_weserbruecke = 'http://pegelonline.wsv.de/webservices/rest-api/v2/stations/GROSSE%20WESERBR%C3%9CCKE.json?includeTimeseries=true&includeCurrentMeasurement=true'

ip_display_bhv_alter_leuchtturm = '192.168.123.50'
ip_display_brake = '192.168.123.51'
ip_display_vegesack = '192.168.123.52'
ip_display_hb_grosse_weserbruecke = '192.168.123.53'

def resetDisplay(ip_display)
  reset_display_arr = [
    0xaa, #Protocol ID: AAh
    0xbb, #Protocol ID: BBh
    0x00, #Sender ID: SIDHI
    0x00, #Sender ID: SIDLO
    0xff, #Receiver ID: RIDHI
    0xff, #Receiver ID: RIDLO
    0x00, #Message Length: LengthHI
    0x01, #Message Length: LengthLO
    0x01, #Header Checksum: LRC
    0x07, #Message Body: FC07 Erase all Display Data
    0x07, #Ending Checksum: CS = FC
  ]
  socket = TCPSocket.new(ip_display, 9100)
  socket.write(reset_display_arr.pack('C*'))
  socket.close
end

def writeText(text, ip_display)
  message_arr =
    [
      0xaa, #Protocol identifier (General Message Format)
      0xbb, #Protocol identifier (General Message Format)
      0x00, #Sender ID
      0x00, #Sender ID
      0xff, #Receiver ID (the display)
      0xff, #Receiver ID (the display)
      0x00, #Length of the Message Body (13h = 19)
      0x13, #Length of the Message Body (13h = 19)
      0x13, #LRC of header (00h^00h^00h^00h^00h^13h)
      0x00, #Send to Initial Segment (FC 00h)
      0x01, #Clear display (CC 01h)
      0x03, #Draw a text string (CC 03h)
      0x00, #Use font 0
      0x03, #Foreground color (3 = Yellow)
      0x00, #Background color (0 = Black)
      0x00, #X = 0
      0x00,  #Y = 0
    ]
  for i in (0...text.size)
    message_arr.push(charToHex(text[i]))
  end
  message_arr.push(0x00) #String terminator
  message_arr.push(0x07) #Show the data on the display (CC 07h)
  message_arr.push(0xe8) #DelayLO
  message_arr.push(0x03) #DelayHI (03E8h = 1000 msec)
  message_arr.push(0x00) #Mode 00h = Instant
  message_arr.push(0x09) #Speed 09h = fastest
  message_arr.push(0x1f) #End of display data (CC 1Fh)
  message_arr.push(0xe6) #Ending Checksum

  message_arr[7] = calculateMessageLength(text)
  message_arr[8] = calculateMessageLrc(message_arr)
  message_arr[message_arr.length - 1] = calculateMessageChecksum(text)

  socket = TCPSocket.new(ip_display, 9100)
  socket.write(message_arr.pack('C*'))
  socket.close
end

def charToHex(c)
  char_set =
    {
      " " => 0x20, "!" => 0x21, "\"" => 0x22, "#" => 0x23, "$" => 0x24, "%" => 0x25, "&" => 0x26, "‘" => 0x27, "(" => 0x28, ")" => 0x29, "*" => 0x2a, "+" => 0x2b, "," => 0x2c, "-" => 0x2d, "." => 0x2e, "/" => 0x2f,
      "0" => 0x30, "1" => 0x31, "2" => 0x32, "3" => 0x33, "4" => 0x34, "5" => 0x35, "6" => 0x36, "7" => 0x37, "8" => 0x38, "9" => 0x39, ":" => 0x3a, ";" => 0x3b, "<" => 0x3c, "=" => 0x3d, ">" => 0x3e, "?" => 0x3f,
      "@" => 0x40, "A" => 0x41, "B" => 0x42, "C" => 0x43, "D" => 0x44, "E" => 0x45, "F" => 0x46, "G" => 0x47, "H" => 0x48, "I" => 0x49, "J" => 0x4a, "K" => 0x4b, "L" => 0x4c, "M" => 0x4d, "N" => 0x4e, "O" => 0x4f,
      "P" => 0x50, "Q" => 0x51, "R" => 0x52, "S" => 0x53, "T" => 0x54, "U" => 0x55, "V" => 0x56, "W" => 0x57, "X" => 0x58, "Y" => 0x59, "Z" => 0x5a, "[" => 0x5b, "\\" => 0x5c, "]" => 0x5d, "^" => 0x5e, "_" => 0x5f,
      "'" => 0x60, "a" => 0x61, "b" => 0x62, "c" => 0x63, "d" => 0x64, "e" => 0x65, "f" => 0x66, "g" => 0x67, "h" => 0x68, "i" => 0x69, "j" => 0x6a, "k" => 0x6b, "l" => 0x6c, "m" => 0x6d, "n" => 0x6e, "o" => 0x6f,
      "p" => 0x70, "q" => 0x71, "r" => 0x72, "s" => 0x73, "t" => 0x74, "u" => 0x75, "v" => 0x76, "w" => 0x77, "x" => 0x78, "y" => 0x79, "z" => 0x7a, "{" => 0x7b, "}" => 0x7d, "˜" => 0x7e, "↓" => 0x9d, "↑" => 0x8d, "←" => 0x90, "→" => 0x91,
    }
  return char_set[c]
end

def calculateMessageLength(text)
  return text.length + 15
end

def calculateMessageLrc(message_arr)
  return message_arr[2] ^ message_arr[3] ^ message_arr[4] ^ message_arr[5] ^ message_arr[6] ^ message_arr[7]
end

def calculateMessageChecksum(text)
  sum = 0x00 ^ 0x01 ^ 0x03 ^ 0x00 ^ 0x03 ^ 0x00 ^ 0x00 ^ 0x00
  for i in (0...text.size)
    sum = sum ^ charToHex(text[i])
  end
  sum = sum ^ 0x00 ^ 0x07 ^ 0xe8 ^ 0x03 ^ 0x00 ^ 0x09 ^ 0x1f
  return sum
end

def getWaterLevel(api_url)
  begin
    data_hash = JSON.parse(Net::HTTP.get(URI(api_url)))
    value = (data_hash['timeseries'][0]['currentMeasurement']['value'] - 500) / 100
    trend = data_hash['timeseries'][0]['currentMeasurement']['trend']
    if trend == -1
      trend = "↓"
    elsif trend == 1
      trend = "↑"
    else
      trend = "←→"
    end
    return value.round(2).to_s + " " + trend
  rescue
    return "No Data"
  end
end

def log(brake_val, bhv_alter_leuchtturm_val, hb_grosse_weserbruecke_val, vegesack_val)
  timestamp = Time.new.to_s
  File.open('displaydata.log', 'a') { |file| file.puts(timestamp + ' : ' + brake_val + ' / ' + bhv_alter_leuchtturm_val + ' / ' + hb_grosse_weserbruecke_val + ' / ' + vegesack_val) }
end


begin
  resetDisplay(ip_display_brake)
  sleep(4)
  brake_val = getWaterLevel(url_brake)
  writeText(brake_val,ip_display_brake)
  sleep(4)
rescue
ensure
end


begin
  resetDisplay(ip_display_bhv_alter_leuchtturm)
  sleep(4)
  bhv_alter_leuchtturm_val = getWaterLevel(url_bhv_alter_leuchtturm)
  writeText(bhv_alter_leuchtturm_val,ip_display_bhv_alter_leuchtturm)
  sleep(4)
rescue
ensure
end

begin
  resetDisplay(ip_display_hb_grosse_weserbruecke)
  sleep(4)
  hb_grosse_weserbruecke_val = getWaterLevel(url_hb_grosse_weserbruecke)
  writeText(hb_grosse_weserbruecke_val,ip_display_hb_grosse_weserbruecke)
  sleep(4)
rescue
ensure
end

begin
  resetDisplay(ip_display_vegesack)
  sleep(4)
  vegesack_val = getWaterLevel(url_vegesack)
  writeText(vegesack_val,ip_display_vegesack)
rescue
ensure
end