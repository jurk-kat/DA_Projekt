with open('data/05_shifts.csv', mode='r', encoding='utf-8') as file:
    text = file.read()
splitted = text.split(",\n")

rest = []
for clen in splitted:
    if clen != ',,,,,,,':
        rest.append(clen)

workers = ['Kaisa', 'Lars Oskar', 'Anne Line', 'Hanne', 'Tiril', 'Andrea', 'Malin', 'Toni'] # da se napsat prikaz, ktery mi to z prvniho sloupecku vybere jako distinct hodnoty? - abych to nemusela vypisovat jako trotl

ships = [item for item in rest if not any(name in item for name in workers)]

ships_out = "\n".join(ships)

with open('data/05_shifts_to_boats.csv', mode='w', encoding='utf-8') as output_file:
    print(ships_out, file=output_file)

# mezikrok v cisteni mezi vysledkem tohoto a vstupnim souborem pro Shifts to boats byl udelat v libre office. Je mozne to udelat v pythonu a jak? Idealne bych to mela cele v jednom souboru, aby to bylo na 1 klik