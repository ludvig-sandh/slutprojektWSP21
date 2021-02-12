require 'sinatra'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require_relative './model.rb'

enable :sessions

#1. Skapa ER + databas som kan hålla användare och tider. Fota ER-diagram, 
#   lägg i misc-mapp
#2. Skapa ett formulär för att registrerara användare.
#3. Skapa ett formulär för att logga in. Om användaren lyckas logga  
#   in: Spara information i session som håller koll på att användaren är inloggad
#4. Låt inloggad användare skapa todos i ett formulär (på en ny sida ELLER på sidan som visar todos.).
#5. Låt inloggad användare updatera och ta bort sina formulär.
#6. Lägg till felhantering (meddelande om man skriver in fel user/lösen)




#NÄSTA GÅNG V.6: Lägg till den funktionen som gör att
#koden i den körs innan varje route (se om inloggad)


#Övriga routes
get('/') do
    redirect('/home')
end

get('/home') do
    slim(:home)
end

get('/error') do
    message = session[:message]
    link_text = session[:link_text]
    if message == nil || link_text == nil
        #Om det i framtiden läggs till flera error-hanterare och man missar att
        #specifiera en beskrivning av felmeddelandet så visas detta som default
        message = "Det har uppstått ett fel, vänligen kontakta Ludvig Sandh."
        link_text = "Hem"
    end
    slim(:"helper/error", locals: {message: message, link_text: link_text})
end

before do
    check_logged_in()
end


#Categories
get('/categories') do
    db = connect_to_db()
    categories = db.execute('SELECT * From Categories')
    p categories
    slim(:"categories/index", locals: {categories: categories})
end

get('/categories/new') do
    #Detta får bara inloggade användare göra
    check_logged_in()

    #Visa formuläret för den som var inloggad
    slim(:"categories/new")
end

#Här visar vi alla tider för en viss kategori
get('/categories/:id') do
    category_id = params[:id]
    
    #Hämta alla tider som finns sparade för denna kategorin
    db = connect_to_db()
    times = db.execute('SELECT * From Times WHERE category_id = ?', category_id)
    
    #Visa dem för användaren
    slim(:"categories/show", locals: {times: times})
end

get('/categories/:id/edit') do
    #slim(:"categories/edit", locals: )
end

post('/categories/:id/update') do
    category_id = params[:id]
    
    #Hämta användar-id: (bara inloggade användare får ändra på en bild)
    user_id = get_user_id()
    
    #Hämta user_id för den som äger denna kategorin
    db = connect_to_db()
    owner_id = db.execute('SELECT user_id From Categories WHERE id = ?', category_id)

    #Dessutom är det naturligtvis bara den som skapat (äger) denna kategorin som kan ändra namnet på den
    if user_id != owner_id
        show_error_message("Du är inte skaparen av denna kategorin. Du kan inte ändra namn på en kategori som någon annan äger", "Hem")
    end
    
    #Användaren är authorized. Hämta datan, dvs det nya namnet på kategorin, från formuläret
    new_cat_name = params[:new_name]

    #Kontrollera att det nya kategorinamnet är tillåtet
    if kategorinamn_accepted?(new_cat_name)

        #Lägg in kategorin i databasen, och omdirigera användaren till kategorisidan
        db.execute('UPDATE Categories SET name = ? WHERE category_id = ?', new_cat_name, category_id)
        redirect('/categories/:id')
    end
end

post('/categories') do
    #Detta får bara inloggade användare göra
    user_id = get_user_id()

    #Hämta data från formuläret
    kategoriNamn = params[:namn]

    #Kontrollera att kategorinamnet är tillåtet
    if kategorinamn_accepted?(kategoriNamn)

        #Lägg in kategorin i databasen, och omdirigera användaren till kategorisidan
        db.execute('INSERT INTO Categories (name, user_id) VALUES (?, ?)', kategoriNamn, user_id)
        redirect('/categories')
    end
end

#Users


#Times