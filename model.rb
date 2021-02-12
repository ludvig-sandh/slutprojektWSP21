#Hjälpfunktioner

#Returnerar en instans av databasen
def connect_to_db()
    path = "db/snabbspringning.db"
    db = SQLite3::Database.new(path)
    db.results_as_hash = true
    return db
end

#Omdirigerar användaren till en sida som visar error
def show_error_message(mes, link_t)
    sessions[:message] = mes
    sessions[:link_text] = link_t
    redirect('/error')
end

#Hämtar användar-id från sessions. Om inget hittas så
#visar vi ett meddelande om det istället och skickar
#till rotrouten
def get_user_id()
    #SÅLÄNGE BARA (hårdkodad inloggning):
    return -1
    user_id = session[:user_id]
    if user_id == nil
        show_error_message("Du är inte inloggad, logga in eller registrera dig för att kunna göra detta", "Hem")
        return
    end
    return user_id
end

#Kallar bara på get_user_id() men i syftet att bara se om 
#användaren är inloggad, inte i syftet att få användar-id:t.
def check_logged_in()
    get_user_id()
end

def kategorinamn_accepted?(kategoriNamn)
    #Om den nya kategorin är tom eller bara innehåller blanksteg, visa felmeddelande
    if kategoriNamn == "" || s =~ /\A\s*\Z/
        show_error_message("En kategori kan inte vara tom. Döp den till något.", "Hem")
    end

    #Kolla att det inte redan finns en kategori med detta namn
    db = connect_to_db()
    categories = db.execute('SELECT * From Categories')
    categories.each do |cat|
        if cat[:name] == kategoriNamn #Annars visa felmeddelande
            show_error_message("Det finns redan en kategori med detta namnet", "Hem")
        end
    end

    return true
end
