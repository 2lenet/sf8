<?php

declare(strict_types=1);

namespace App\Form\Crudit;

use Lle\CruditBundle\Form\Type\FileType;
use Symfony\Component\Form\AbstractType;
use Symfony\Component\Form\FormBuilderInterface;

class PdfModelType extends AbstractType
{
    public function buildForm(FormBuilderInterface $builder, array $options): void
    {
        $builder->add('libelle');
        $builder->add('code');
        $builder->add('file', FileType::class);
        $builder->add('description');
    }

    public function getName(): string
    {
        return 'pdfmodel_form';
    }
}
