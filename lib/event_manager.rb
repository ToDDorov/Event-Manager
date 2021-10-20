require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'time'
require 'date'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_homephone(phone)
  phone_copy = phone.split(/[(){}\[\]\s+.,-]/).join

  if phone_copy.length > 9 && phone_copy.length < 12
    if phone_copy.length == 10
      return phone_copy
    elsif phone_copy.length == 11 && phone_copy[0].to_i != 1
      return phone_copy[1..10]
    end
  end

  'Unavailable'
end

def legislators_by_zipcode(zipcode)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zipcode,
      levels: 'country',
      roles: %w[legislatorUpperBody legislatorLowerBody]
    ).officials
  rescue StandardError
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def update_day_hash(hash, regdate)
  day = Date.strptime(regdate, '%m/%d/%Y').day

  if hash[day].nil?
    hash[day] = 1
  elsif hash[day] += 1
  end

  hash
end

def update_hour_hash(hash, reghour)
  hour = Time.parse(reghour).hour

  if hash[hour].nil?
    hash[hour] = 1
  elsif hash[hour] += 1
  end

  hash
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

puts 'Event Manager Initialized'

attendees_file = 'event_attendees.csv'

if File.exist?(attendees_file)
  template_letter = File.read('form_letter.erb')
  erb_template = ERB.new template_letter

  contents = CSV.open(attendees_file, headers: true, header_converters: :symbol)
  users_reg_by_day = {}
  users_reg_by_hour = {}

  contents.each do |row|
    id = row[0]
    name = row[:first_name]
    zipcode = clean_zipcode(row[:zipcode])
    phone = clean_homephone(row[:homephone])
    legislators = legislators_by_zipcode(zipcode)
    regdate = row[:regdate].split(' ')[0]
    reghour = row[:regdate].split(' ')[1]

    users_reg_by_day = update_day_hash(users_reg_by_day, regdate)
    users_reg_by_hour = update_hour_hash(users_reg_by_hour, reghour)

    form_letter = erb_template.result(binding)

    save_thank_you_letter(id, form_letter)
  end

  users_reg_by_day = users_reg_by_day.sort_by { |_k, v| [-v] }
  users_reg_by_hour = users_reg_by_hour.sort_by { |_k, v| [-v] }

  puts "Most busy reg day is #{users_reg_by_day[0][0]}"
  puts "Most busy reg hour is #{users_reg_by_hour[0][0]}"
end
