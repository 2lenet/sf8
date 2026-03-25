<?php

declare(strict_types=1);

namespace App\Form\Crudit;

use Symfony\Component\Form\AbstractType;
use Symfony\Component\Form\FormBuilderInterface;

class GroupType extends AbstractType
{
    public function buildForm(FormBuilderInterface $builder, array $options): void
    {
        $builder->add('name');
        $builder->add('label');
        $builder->add('requiredRole');
        $builder->add('rank');
        $builder->add('active');
        $builder->add('isRole');
    }

    public function getName(): string
    {
        return 'group_form';
    }
}
