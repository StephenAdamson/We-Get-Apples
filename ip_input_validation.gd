extends LineEdit

# Regular expression to match a valid IPv4 address or hostname with an optional port
var ip_or_hostname_regex = RegEx.new()
var last_change = 0
var current_text = ""
var requested = false

# Flags to track if both HTTP and HTTPS were attempted
var http_tried = false
var https_tried = false

# Store the result of both attempts
var http_success = false
var https_success = false

# Button enablement
var valid_hostname = false 

func _ready():
	$JoinButton.disabled = false
	$JoinButton.text = "Host"
	$HTTPRequest.request_completed.connect(_on_request_completed)
	ip_or_hostname_regex.compile(r"^(https?:\/\/)?" +                        # Optional http:// or https://
					  r"((([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}|localhost)|" +      # Hostnames/domains (e.g., example.com)
					  r"((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}" +     # IPv4 address
					  r"(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))" +           # IPv4 continued
					  r"(:[0-9]{1,5})?$")                                    # Optional port number

func _process(_delta):
	if not current_text.is_empty() && Time.get_unix_time_from_system() - last_change > .3 and Time.get_unix_time_from_system() - last_change < .5 and not requested and ip_or_hostname_regex.search(current_text):
		# Reset flags for new request
		requested = true
		http_tried = false
		https_tried = false
		http_success = false
		https_success = false

		if current_text.begins_with("http://") or current_text.begins_with("https://"):
			checkLive(current_text)  # If protocol is provided, just test it
		else:
			# Try both http and https if no protocol is provided
			checkLive("http://" + current_text, "http")
			checkLive("https://" + current_text, "https")

func _on_text_changed(new_text):
	if new_text == "":
		$JoinButton.text = "Host"

	if not ip_or_hostname_regex.search(new_text):
		self.add_theme_color_override("font_color", Color(0.77, 0.33, 0.33)) # Change color to red for invalid input
	else:
		requested = false
		current_text = new_text
		self.add_theme_color_override("font_color", Color(0.77, 0.77, 0.33)) # Change color to yellow for valid input, untested
	
	last_change = Time.get_unix_time_from_system()

func checkLive(ip: String, protocol_type: String = ""):
	if protocol_type == "http":
		http_tried = true
	elif protocol_type == "https":
		https_tried = true
	
	$HTTPRequest.request(ip)

func _on_request_completed(_result, response_code, _headers, _body):
	if response_code >= 200 and response_code < 300:
		if current_text.begins_with("http://"):
			http_success = true
		elif current_text.begins_with("https://"):
			https_success = true

		# Update the color to green if any attempt is successful
		self.add_theme_color_override("font_color", Color(0.33, 0.77, 0.33)) # Change color to green for valid input, tested
		$JoinButton.text = "Join"
		$JoinButton.disabled = false
	else:
		# Check if both HTTP and HTTPS have been attempted
		if http_tried and https_tried:
			if not http_success and not https_success:
				# If both failed, change color to red
				self.add_theme_color_override("font_color", Color(0.77, 0.33, 0.33)) # Change color to red for failed ping test
				$JoinButton.text = "Join"
				$JoinButton.disabled = true
