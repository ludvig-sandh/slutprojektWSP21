#Hjälpfunktioner

#Returnerar en instans av databasen
def connect_to_db()
    path = "db/snabbspringning.db"
    db = SQLite3::Database.new(path)
    db.results_as_hash = true
    return db
end



#Hämtar användar-id från sessions. Om inget hittas så
#visar vi ett meddelande om det istället och skickar användaren till route_back som tas som argument
def get_user_id()
    user_id = session[:user_id]
    if user_id == nil
        display_information("Du är inte inloggad, logga in eller registrera dig för att kunna göra detta", "Hem", "/login")
        return
    end
    return user_id
end

#Kallar bara på get_user_id() men i syftet att bara se om 
#användaren är inloggad, inte i syftet att få användar-id:t.
#Denna funktionen gör alltså exakt samma sak som get_user_id()
#men används i ett annat syfte och har därför ett mer passande namn
def check_logged_in()
    get_user_id()
end

def kategorinamn_accepted?(kategorinamn)
    #Om den nya kategorin är tom eller bara innehåller blanksteg, visa felmeddelande
    if kategorinamn == "" || kategorinamn =~ /\A\s*\Z/
        display_information("En kategori kan inte vara tom. Döp den till något.", "Tillbaka", "/categories/new")
        return false
    end

    #Kolla att det inte redan finns en kategori med detta namn
    db = connect_to_db()
    categories = db.execute('SELECT * From Categories')
    categories.each do |cat|
        if cat["name"].downcase == kategorinamn.downcase #Annars visa felmeddelande. Jag väljer att räkna två namn som samma utan hänsyn till gemener/versaler
            display_information("Det finns redan en kategori med detta namnet", "Tillbaka", "/categories/new")
            return false
        end
    end

    return true
end

#Tar en array med timmar, minuter, sekunder & hundradelar
def check_time_input_accepted(time_input, category_id)
    time_input.each do |time|
        if time < 0
            display_information("Din tid kan inte vara negativ", "Tillbaka", "/times/#{category_id}/new")
            return
        end
    end
    hours, minutes, seconds, fractions = time_input

    if hours > 2000
        display_information("Din tid kan inte överstiga 2000 timmar.", "Tillbaka", "/times/#{category_id}/new")
        return
    end
    if minutes >= 60 || seconds >= 60 || fractions >= 100
        display_information("Fel, du måste skriva på rätt format, där minuter/sekunder är mindre än 60 och hundradelar är mindre än 100", "Tillbaka", "/times/#{category_id}/new")
        return
    end
end

def time_to_string(h, m, s, f)
    return "#{h}:#{m / 10}#{m % 10}:#{s / 10}#{s % 10}.#{f / 10}#{f % 10}"
end

def parsetime(time)
    l = time.split(".")
    h, m, s = l[0].split(":").map(&:to_i)
    f = l[1].to_i
    return f + s * 100 + m * 6000 + h * 360000
end

def sort_times(times)
    times.sort! do |a, b|
        a_time, b_time = parsetime(a["time"]), parsetime(b["time"])
        if a_time == b_time
            date_a, date_b = DateTime.parse(a["date"]), DateTime.parse(b["date"])
            seconds_a, seconds_b = date_a.strftime('%s'), date_b.strftime('%s')
            seconds_a <=> seconds_b
        else
            a_time <=> b_time
        end
    end
end

def insert_into_DB(entitet, attribut, värden)
    # command = "INSERT INTO " + entitet + " ("
    # command += attribut.join(", ")
    # command += " VALUES ("
    # command += ("?" * värden.length).join(", ")
    # command += ")"
    # p command
    #...
    #Hur kan jag använda en array av värden som argument? Answer: Gör det inte
    # db.execute(command, ?, ?)
end

def get_user_with_id(id)
    owner = db.execute('SELECT username From Users WHERE id = ?', id).first
    return owner
end

def get_form_time_info()
    return [params[:hours], params[:minutes], params[:seconds], params[:fractions].to_i].map(&:to_i)
end