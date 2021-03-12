#Hjälpfunktioner

#Returnerar en instans av databasen
def connect_to_db()
    path = "db/snabbspringning.db"
    db = SQLite3::Database.new(path)
    db.results_as_hash = true
    return db
end

#Omdirigerar användaren till en sida som visar error
def show_error_message(mes, link_t, link)
    session[:message] = mes
    session[:link_text] = link_t
    session[:link] = link
    redirect('/error')
end

#Hämtar användar-id från sessions. Om inget hittas så
#visar vi ett meddelande om det istället och skickar
#till rotrouten
def get_user_id()
    #SÅLÄNGE BARA (hårdkodad inloggning):
    return 0
    user_id = session[:user_id]
    if user_id == nil
        show_error_message("Du är inte inloggad, logga in eller registrera dig för att kunna göra detta", "Hem", "/home")
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
        show_error_message("En kategori kan inte vara tom. Döp den till något.", "Tillbaka", "/categories/new")
    end

    #Kolla att det inte redan finns en kategori med detta namn
    db = connect_to_db()
    categories = db.execute('SELECT * From Categories')
    categories.each do |cat|
        if cat[:name] == kategorinamn #Annars visa felmeddelande
            show_error_message("Det finns redan en kategori med detta namnet", "Tillbaka", "/categories/new")
        end
    end

    return true
end

#Tar en array med timmar, minuter, sekunder & hundradelar
def time_input_accepted?(time_input, category_id)
    time_input.each do |time|
        if time < 0
            show_error_message("Din tid kan inte vara negativ", "Tillbaka", "/times/#{category_id}/new")
            return false
        end
    end
    hours = time_input[0]
    minutes = time_input[1]
    seconds = time_input[2]
    fractions = time_input[3]

    if hours > 2000
        show_error_message("Din tid kan inte överstiga 2000 timmar.", "Tillbaka", "/times/#{category_id}/new")
        return false
    end
    if minutes >= 60 || seconds >= 60 || fractions >= 100
        show_error_message("Fel, du måste skriva på rätt format, där minuter/sekunder är mindre än 60 och hundradelar är mindre än 100", "Tillbaka", "/times/#{category_id}/new")
        return false
    end
    return true
end

def time_to_string(h, m, s, f)
    return "#{h}:#{m / 10}#{m % 10}:#{s / 10}#{s % 10}.#{f / 10}#{f % 10}"
end


def insertIntoDB(entitet, attribut, värden)
    command = "INSERT INTO " + entitet + " ("
    command += attribut.join(", ")
    command += " VALUES ("
    command += ("?" * värden.length).join(", ")
    command += ")"
    p command
    #...
    #Hur kan jag använda en array av värden som argument?
end

def getUserWithId(id)
    owner = db.execute('SELECT username From Users WHERE id = ?', id).first
    return owner
end