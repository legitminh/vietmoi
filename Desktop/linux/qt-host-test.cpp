#include <QApplication>
#include <QLineEdit>
#include <QVBoxLayout>
#include <QWidget>
#include <fstream>
int main(int argc, char **argv) {
    QApplication app(argc,argv);
    const std::string output=argc>1?argv[1]:"/tmp/sieuviet-host.txt";
    QWidget window;window.setWindowTitle("Sieuviet host test");window.resize(700,220);
    auto *box=new QVBoxLayout(&window);auto *first=new QLineEdit;auto *second=new QLineEdit;
    box->addWidget(first);box->addWidget(second);
    QObject::connect(first,&QLineEdit::textChanged,[output](const QString &value) { std::ofstream(output)<<value.toUtf8().constData(); });
    QObject::connect(second,&QLineEdit::textChanged,[output](const QString &value) { std::ofstream(output+".second")<<value.toUtf8().constData(); });
    window.show();first->setFocus();return app.exec();
}
